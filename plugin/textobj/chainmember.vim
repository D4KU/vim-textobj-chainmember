if exists('g:loaded_textobj_chainmember')
    finish
endif

if exists(':NeoBundleDepends') == 2
    NeoBundleDepends 'kana/vim-textobj-user'
endif

call textobj#user#plugin('chainmember', {
    \   '-': {
    \     'select-a-function': 'textobj#chainmember#select_a',
    \     'select-a': 'am',
    \     'select-i-function': 'textobj#chainmember#select_i',
    \     'select-i': 'im',
    \   },
    \   'next': {
    \     'select-a-function': 'textobj#chainmember#select_an',
    \     'select-a': 'anm',
    \     'select-i-function': 'textobj#chainmember#select_in',
    \     'select-i': 'inm',
    \   },
    \   'last': {
    \     'select-a-function': 'textobj#chainmember#select_al',
    \     'select-a': 'alm',
    \     'select-i-function': 'textobj#chainmember#select_il',
    \     'select-i': 'ilm',
    \   },
    \ })

let g:loaded_textobj_chainmember = 1
