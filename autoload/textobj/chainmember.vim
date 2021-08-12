" 1 if debug highlighting should be enabled
let s:debug = 0
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
        " If cache isn't set, exhibit standard behavior
        if (a:brack.cache == 0)
            " an opening bracket increases the level
            let a:brack.lvl += 1
        else
            " load level from cache, empty cache
            let a:brack.lvl = a:brack.cache
            let a:brack.cache = 0
        endif
        let a:brack.lastopen = 1
        return 1
    elseif (a:char == a:brack.close)
        " If a closer is encountered in front of an opener, the current
        " level is cached and 'lvl' is set to 1. When the next opener is
        " found, the cached level is applied again to 'lvl'. This is to treat
        " calls like 'curry()()' as one unit.  Otherwise the back parser would
        " stop at the first opening bracket found.
        if (a:brack.lastopen && a:backwards)
            let a:brack.cache = a:brack.lvl
            let a:brack.lvl = -1
        else
            " a closing bracket increases the level
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
function! s:main(a, shift) abort
    " consider 'open' and 'close' as constant, the other values are used to
    " save runtime state
    " * lvl: How many layers deep in the bracket hierarchy in the parser?
    " * cache: Relevant when parsing backwards. See comments in
    "   's:update_brackets_inner'
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

    " all characters of the current line
    let l:line = getline('.')

    " parse backward from cursor position ====================================
    " 1 if first character is a terminator
    let l:start_at_terminator = 0
    " 1 if first character is a dot
    let l:dot_start = 0
    " 1 if cursor is directly on terminator
    let l:cursor_at_terminator = 0
    " later stages of the algorithm can offset the start position when they
    " gather new information
    let l:start_offset = 0
    " 1 as long character under cursor is parsed, i.e. in the first loop
    let l:at_cursor = 1
    " future start position of text object
    let l:start = col('.')
    " future end position of text object
    let l:end = col('.')
    " counts how many dots have been encountered
    let l:dot_count = 0

    if (a:shift <= 0)
        while 0 < l:start
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
                        let l:dot_count -= 1

                        " e.g. shift == -1: end at first dot found
                        if (a:shift == l:dot_count)
                            let l:end = l:start
                        " because shift can only be 0 or negative here:
                        " read as: abs(a:shift) < abs(l:dot_count)
                        elseif (a:shift > l:dot_count)
                            " if it's an 'a' text object (as in 'am') we
                            " include the dot, if not, 0 is added
                            let l:start_offset -= a:a
                            let l:dot_start = 1
                            break
                        endif
                    elseif (l:char =~ s:terminators)
                        let l:start_offset -= a:a
                        let l:cursor_at_terminator = l:at_cursor
                        let l:start_at_terminator = 1
                        break
                    elseif (s:isin(s:openers, l:char) && !l:at_cursor)
                        " we thought we are outside brackets, but we found an
                        " opener to the left
                        break
                    endif
                endif
                call s:update_brackets(l:char, 1)
            endif

            let l:at_cursor = 0
            let l:start -= 1
        endwhile
    endif

    " 0 if even count of quotes has been found on forward parsing
    let l:uneven_quotes = 0

    if (l:cursor_at_terminator)
        " skip forward parsing if cursor over terminator or shift is negative
        " convert 1-based to 0-based index
        let l:end -= 1
    elseif (a:shift < 0)
        " if we didn't stop at a dot in the forward
        " parse, the cursor is on a first chain member, so
        " we include the dot after it instead.
        " also: convert 1-based to 0-based index
        let l:end += !l:dot_start - 1
    else
        " parse forward from cursor position =================================
        let l:dot_count = 0
        while l:end < len(l:line)
            " for the end position we don't convert 1-based index to 0-based
            " so we sample the line one character ahead
            let l:char = l:line[l:end]

            " update s:quotes state
            if (s:update_quotes(l:char))
                " current char is a quote
                let l:uneven_quotes = !l:uneven_quotes
            endif

            if (s:outside_quotes())
                if (s:outside_brackets(0))
                    if (l:char == '.')
                        let l:dot_count += 1

                        " e.g. shift == 1: start at first dot found
                        if (a:shift == l:dot_count)
                            " 'inner' object starts 1 letter later
                            let l:start = l:end + !a:a
                        endif

                        " skip over Nth dot if given member count is greater N,
                        " shift can make us skip over dots even if count is
                        " small enough
                        if (l:dot_count >= v:count1 + a:shift)
                            if (a:a)
                                " if we didn't stop at a dot in the forward
                                " parse, the cursor is on a first chain member, so
                                " we include the dot after it instead
                                let l:end += !l:dot_start
                                " in this case, we also don't include white space
                                " in front of the word
                                let l:start_offset += l:start_at_terminator
                            endif
                            break
                        endif
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
        " if an uneven quote count was encountered during forward parsing
        " and backward parsing found at least one, we assume we are inside of
        " quotes and set 'l:start' to the first quotes found by the backward
        " pass
        let l:start = l:quote_start

        " recalculate 'start_at_terminator' with new 'l:start'
        if (l:line[l:start - 1] =~ s:terminators)
            let l:start_offset -= a:a
        endif
    endif

    " build return array needed by 'textobj-user' plugin
    let l:head = getpos('.')
    let l:tail = getpos('.')
    let l:head[2] = l:start + l:start_offset + 1
    let l:tail[2] = l:end
    return ['v', l:head, l:tail]
endfunction

function! textobj#chainmember#select_il()
    return s:main(0, -1)
endfunction
function! textobj#chainmember#select_al()
    return s:main(1, -1)
endfunction
function! textobj#chainmember#select_i()
    return s:main(0, 0)
endfunction
function! textobj#chainmember#select_a()
    return s:main(1, 0)
endfunction
function! textobj#chainmember#select_in()
    return s:main(0, 1)
endfunction
function! textobj#chainmember#select_an()
    return s:main(1, 1)
endfunction

" highlight the text object with the 'ChainMember' highlight group
function! s:debug()
    let l:ret = textobj#chainmember#select_a()
    let l:line  = l:ret[1][1]
    let l:start = l:ret[1][2]
    let l:end   = l:ret[2][2] + 1
    call clearmatches()
    call matchaddpos('ChainMember', [[l:line, l:start, l:end - l:start]])
endfunction

if (s:debug)
    highlight ChainMember cterm=italic ctermbg=236
    " execute debug function on every cursor update
    augroup s:chainmember
        autocmd!
        autocmd! CursorMoved * call s:debug()
    augroup END
endif
