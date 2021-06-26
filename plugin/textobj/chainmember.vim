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
    \     'scan': 'cursor',
    \   },
    \ })

let g:loaded_textobj_chainmember = 1
