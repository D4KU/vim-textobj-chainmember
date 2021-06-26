let s:debug = 1
let s:terminators = '[;,[:blank:]]'

function! s:update_level(char)
    if (a:char == '(')
        let s:paran_lvl += 1
    elseif (a:char == ')')
        let s:paran_lvl -= 1
    elseif (a:char == '[')
        let s:brack_lvl += 1
    elseif (a:char == ']')
        let s:brack_lvl -= 1
    elseif (a:char == '{')
        let s:brace_lvl += 1
    elseif (a:char == '}')
        let s:brace_lvl -= 1
    elseif (a:char =~ '<')
        let s:angle_lvl += 1
    elseif (a:char == '>')
        let s:angle_lvl -= 1
    endif
endfunction

function! s:main(a)
    let s:paran_lvl = 0
    let s:brack_lvl = 0
    let s:brace_lvl = 0
    let s:angle_lvl = 0

    let l:line = getline('.')
    let l:cursor = getpos('.')[2]
    let l:start = l:cursor

    " backward
    let hitspace = 0
    let onterminator = 0
    while l:start > 0
        let char = l:line[l:start - 1]
        if (s:paran_lvl >= 0 &&
          \ s:brack_lvl >= 0 &&
          \ s:brace_lvl >= 0 &&
          \ s:angle_lvl >= 0)
            if (char == '.')
                let l:start -= a:a
                break
            elseif (char =~ s:terminators)
                let hitspace = 1
                let onterminator = l:start == l:cursor
                let l:start -= a:a
                break
            elseif (char =~ '[({<\[]' && l:start != l:cursor)
                break
            endif
        endif

        call s:update_level(char)
        let l:start -= 1
    endwhile

    let l:end = l:cursor
    if (onterminator)
        let l:end -= 1
    else
        " forward
        while l:end < len(l:line)
            let char = l:line[l:end]
            if (s:paran_lvl <= 0 &&
              \ s:brack_lvl <= 0 &&
              \ s:brace_lvl <= 0 &&
              \ s:angle_lvl <= 0)
                if (char == '.')
                    if (a:a)
                        let l:end += hitspace || l:start == 0
                        let l:start += hitspace
                    endif
                    break
                elseif (char =~ s:terminators || char =~ '[)}>\]]')
                    break
                endif
            endif

            call s:update_level(char)
            let l:end += 1
        endwhile
    endif

    let l:head = getpos('.')
    let l:tail = copy(l:head)
    let l:head[2] = l:start + 1
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
