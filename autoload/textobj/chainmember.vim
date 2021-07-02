" 1 if debug highlighting should be enabled
let s:debug = 1
" when this regex matches, parsing is stopped
let s:terminators = '[;,[:blank:]]'

" inner function of 'update_brackets'
" parameters:
" * char: current character to parse
" * brack: object in 'brackets' list to compare 'char' to
" * backwards: 1 if parsing backwards
" returns 1 if 'char' is a bracket at all
function! s:update_brackets_inner(char, brack, backwards)
    if (a:char == a:brack.open)
        if (a:brack.cache == 0)
            let a:brack.lvl += 1
        else
            let a:brack.lvl = a:brack.cache
            let a:brack.cache = 0
        endif
        let a:brack.lastopen = 1
        return 1
    elseif (a:char == a:brack.close)
        if (a:brack.lastopen && a:backwards)
            let a:brack.cache = a:brack.lvl
            let a:brack.lvl = -1
        else
            let a:brack.lvl -= 1
        endif
        let a:brack.lastopen = 0
        return 1
    endif
    return 0
endfunction

" update bracket state considering the newest bit of information, the last
" parsed character 'char'
" parameters:
" * char: current character to parse
" * backwards: 1 if parsing backwards
" returns 1 if 'char' is a bracket at all
function! s:update_brackets(char, backwards)
    for l:b in s:brackets
        if (s:update_brackets_inner(a:char, l:b, a:backwards))
            return 1
        endif
    endfor
    return 0
endfunction

" update quote state
" returns 1 if the passed character is a quote
function! s:update_quotes(char)
    for l:q in s:quotes
        if (l:q.char == a:char)
            let l:q.outside = !l:q.outside
            return 1
        endif
    endfor
    return 0
endfunction

" Returns 1 if 'needle' is a character in 'haystack'
function! s:isin(haystack, needle)
    return stridx(a:haystack, a:needle) >= 0
endfunction

" Returns 1 if the parser is currently outside every variant of quoted area
" specified in 's:quotes'
" Since it starts parsing from the cursor position, 'is' should be understood
" as 'to the best of his knowledge'.
function! s:outside_quotes()
    for l:q in s:quotes
        if (!l:q.outside)
            return 0
        endif
    endfor
    return 1
endfunction

" Returns 1 if the parser is currently outside every sort of bracket pair
" specified in 's:brackets'.
" Being 'outside' means considering terminators, being 'inside' means ignoring
" them until a closing bracket was found.
function! s:outside_brackets(backwards)
    for l:b in s:brackets
        " When backwards parsing, we are inside if more closers than openers
        " were found, i.e. the level is negative.
        " When forwards parsing, we are inside if more openers than closers
        " were found, i.e. the level is positive.
        if (a:backwards ? (l:b.lvl < 0) : (l:b.lvl > 0))
            return 0
        endif
    endfor
    return 1
endfunction

" core algorithm
" The current implementation parses backwards to the left of the cursor
" position und forwards to the right from it, only in the current line.
" In retrospect, the code were probably of better quality if I would first
" parse the whole statement under the cursor (which might span several lines)
" from start to finish and then query the cursor position in it. You always
" know better afterwards.
function! s:main(a) abort
    " consider 'open' and 'close' as constant, the other values are used to
    " save runtime state
    " * lvl: How many layers deep in the bracket hierarchy in the parser?
    " * cache: Relevant when parsing backwards. If a closer is encountered
    "   after (in front of) an opener, the current level is cached and 'lvl'
    "   is set to -1. When the next opener is found, the cached level is
    "   applied again to 'lvl'. This is to treat calls like 'curry()()' as
    "   one unit. Otherwise the back parser would stop at the first opening
    "   bracket found.
    " * lastopen: 1 if the lastly encountered bracket was an opener
    let s:brackets = [
        \ { 'open': '(', 'close': ')', 'lvl': 0, 'cache': 0, 'lastopen': 0 },
        \ { 'open': '[', 'close': ']', 'lvl': 0, 'cache': 0, 'lastopen': 0 },
        \ { 'open': '{', 'close': '}', 'lvl': 0, 'cache': 0, 'lastopen': 0 },
        \ { 'open': '<', 'close': '>', 'lvl': 0, 'cache': 0, 'lastopen': 0 },
        \ ]
    " consider 'char' as constant and 'outside' to save runtime state,
    " storing whether the parser is outside a quoted area
    let s:quotes = [
        \ { 'char': '"', 'outside': 1 },
        \ { 'char': "'", 'outside': 1 },
        \ ]

    " assemble all opening and closing brackets for later usage
    let s:closers = ''
    let s:openers = ''
    for l:b in s:brackets
        let s:openers = s:openers . l:b.open
        let s:closers = s:closers . l:b.close
    endfor

    let l:line = getline('.')
    let l:start = col('.')

    " parse backward from cursor position ====================================
    " 1 if first character is a terminator
    let l:start_at_terminator = 0
    " 0 if first character is a dot, 1 otherwise
    let l:no_dot_start = 0
    " 1 if cursor is directly on terminator
    let l:cursor_at_terminator = 0
    " later stages of the algorithm can offset the start position when they
    " gather new information
    let l:start_offset = 0
    " 1 as long character under cursor is parsed, i.e. in the first loop
    let l:at_cursor = 1
    while l:start > 0
        " col('.') is index 1 based, array access index 0: so we subtract 1
        let l:char = l:line[l:start - 1]

        " save the position of the first encountered quote
        " so later, with more information, we can jump back to it
        if (s:update_quotes(l:char) && !exists('l:quote_start'))
            let l:quote_start = l:start - 1
        endif

        " we can only break out of the loop earlier if we are not in a quoted
        " area or between quotes
        if (s:outside_quotes())
            if (s:outside_brackets(1))
                if (l:char == '.')
                    " if it's an 'a' text object (as in 'am') we include the
                    " dot, if not, 0 is added
                    let l:start_offset -= a:a
                    break
                elseif (l:char =~ s:terminators)
                    let l:start_offset -= a:a
                    let l:cursor_at_terminator = l:at_cursor
                    let l:start_at_terminator = 1
                    let l:no_dot_start = 1
                    break
                elseif (s:isin(s:openers, l:char) && !l:at_cursor)
                    " we thought we are outside brackets, but we found an
                    " opener to the left
                    let l:no_dot_start = 1
                    break
                endif
            endif
            call s:update_brackets(l:char, 1)
        endif

        let l:at_cursor = 0
        let l:start -= 1
    endwhile

    let l:end = col('.')
    let l:uneven_quotes = 0
    if (l:cursor_at_terminator)
        let l:end -= 1
    else
        " forward
        while l:end < len(l:line)
            let l:char = l:line[l:end]

            if (s:update_quotes(l:char))
                let l:uneven_quotes = !l:uneven_quotes
            endif

            if (s:outside_quotes())
                if (s:outside_brackets(0))
                    if (l:char == '.')
                        if (a:a)
                            let l:end += l:no_dot_start || l:start == 0
                            let l:start_offset += l:start_at_terminator
                        endif
                        break
                    elseif (l:char =~ s:terminators || s:isin(s:closers, l:char))
                        break
                    endif
                endif
                " this is called after 's:outside_brackets()' is queried to only
                " consider breaking on a closing bracket, not in front of it
                call s:update_brackets(l:char, 0)
            endif

            let l:end += 1
        endwhile
    endif

    if (l:uneven_quotes && exists('l:quote_start'))
        let l:start = l:quote_start

        " recalculate 'start_at_terminator' with new 'start'
        if (l:line[l:start - 1] =~ s:terminators)
            let l:start_offset -= a:a
        endif
    endif

    let l:head = getpos('.')
    let l:tail = getpos('.')
    let l:head[2] = l:start + l:start_offset + 1
    let l:tail[2] = l:end
    return ['v', l:head, l:tail]
endfunction

function! s:debug()
    let l:ret = textobj#chainmember#select_a()
    let l:line  = l:ret[1][1]
    let l:start = l:ret[1][2]
    let l:end   = l:ret[2][2] + 1
    call clearmatches()
    call matchaddpos('ChainMember', [[l:line, l:start, l:end - l:start]])
endfunction

function! textobj#chainmember#select_i()
    return s:main(0)
endfunction

function! textobj#chainmember#select_a()
    return s:main(1)
endfunction

if (s:debug)
    highlight ChainMember cterm=italic ctermbg=236
    augroup s:chainmember
        autocmd!
        autocmd! CursorMoved * call s:debug()
    augroup END
endif
