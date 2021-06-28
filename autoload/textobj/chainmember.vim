let s:debug = 1
let s:terminators = '[;,[:blank:]]'

function! s:inner(char, brack, backwards)
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

function! s:update_brackets(char, backwards)
    for l:b in s:brackets
        if (s:inner(a:char, l:b, a:backwards))
            return 1
        endif
    endfor
    return 0
endfunction

function! s:update_quotes(char)
    for l:q in s:quotes
        if (l:q.char == a:char)
            let l:q.outside = !l:q.outside
            return 1
        endif
    endfor
    return 0
endfunction

function! s:isin(haystack, needle)
    return stridx(a:haystack, a:needle) >= 0
endfunction

function! s:outside_quotes()
    let l:outside_quote = 1
    for l:q in s:quotes
        let l:outside_quote = l:outside_quote && l:q.outside
    endfor
    return l:outside_quote
endfunction

function! s:outside_brackets(backwards)
    let l:outside_brack = 1
    for l:b in s:brackets
        let l:lvl_valid = a:backwards ? (l:b.lvl >= 0) : (l:b.lvl <= 0)
        let l:outside_brack = l:outside_brack && l:lvl_valid
    endfor
    return l:outside_brack
endfunction

function! s:main(a) abort
    let s:brackets = [
        \ { 'open': '(', 'close': ')', 'lvl': 0, 'cache': 0, 'lastopen': 0 },
        \ { 'open': '[', 'close': ']', 'lvl': 0, 'cache': 0, 'lastopen': 0 },
        \ { 'open': '{', 'close': '}', 'lvl': 0, 'cache': 0, 'lastopen': 0 },
        \ { 'open': '<', 'close': '>', 'lvl': 0, 'cache': 0, 'lastopen': 0 },
        \ ]
    let s:quotes = [
        \ { 'char': '"', 'outside': 1 },
        \ { 'char': "'", 'outside': 1 },
        \ ]
    let s:closers = ''
    let s:openers = ''
    for l:b in s:brackets
        let s:openers = s:openers . l:b.open
        let s:closers = s:closers . l:b.close
    endfor

    let l:line = getline('.')
    let l:start = col('.')

    " backward
    let l:terminator_start = 0
    let l:no_dot_start = 0
    let l:at_terminator = 0
    let l:start_offset = 0
    let l:at_cursor = 1
    while l:start > 0
        let l:char = l:line[l:start - 1]

        if (s:update_quotes(l:char) && !exists('l:quote_start'))
            let l:quote_start = l:start - 1
        endif

        if (s:outside_quotes())
            if (s:outside_brackets(1))
                if (l:char == '.')
                    let l:start_offset = -a:a
                    break
                elseif (l:char =~ s:terminators)
                    let l:at_terminator = l:at_cursor
                    let l:start_offset -= a:a
                    let l:terminator_start = 1
                    let l:no_dot_start = 1
                    break
                elseif (s:isin(s:openers, l:char) && !l:at_cursor)
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
    if (l:at_terminator)
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
                            let l:start_offset += l:terminator_start
                        endif
                        break
                    elseif (l:char =~ s:terminators || s:isin(s:closers, l:char))
                        break
                    endif
                endif
                call s:update_brackets(l:char, 0)
            endif

            let l:end += 1
        endwhile
    endif

    if (l:uneven_quotes && exists('l:quote_start'))
        let l:start = l:quote_start

        " recalculate 'terminator_start' with new 'start'
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
    let l:ret = textobj#chainmember#select_i()
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
