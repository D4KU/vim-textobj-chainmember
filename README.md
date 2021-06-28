This Vim plugin provides text objects for chain members: `im` and `am`. It
depends on the [textobj-user](https://github.com/kana/vim-textobj-user)
plugin.

## What the heck is a chain member?

There is no established terminology, so I made one up. You know method
chaining as in `foo.bar().baz()`, right? A member chain is an abstraction
of that, because such a chain could also consist of attributes, fields,
properties, however you want to call variables of a class. A chain member then
is just a member in a member chain. Easy. :)

## What this plugin can do

Why not just use [targets.vim](https://github.com/wellle/targets.vim)'s `i.` and `a.`?
Let me show a few examples, in the fantastic notation of that plugin.

For `am`, the first chain member includes the dot to its right:
```
cursor position │ .....
buffer line     │ first.second.third
selection       │ └ am ┘
```

..., all following members the one to their left:
```
     .......
first.second.third
     └ am ─┘
```

`im` does not include the dot:
```
     .......
first.second.third
      └ im ┘
```

Method calls can be selected outside their argument list:
```
     ........          .
first.second(arg1, arg2).third
     └────── am ───────┘
```

Dots and other special characters inside the argument list are skipped:
```
     ........               .
first.second(arg1.var, foo()).third
     └───────── am ─────────┘
```

Inside the argument list, the outside is ignored:
```
             ......
first.second(foobar.var, arg2).third
             └ am ─┘
```

Chars and string contents are ignored:
```
     ........         .
first.second(") ", '.').third
     └────── am ──────┘
```

Type parameters are no problem, either:
```
     ........              ...
first.second<Type.InnerType>().third
     └────────── am ─────────┘
```

..., nor are (multi-dimensional) arrays:
```
     ........         .. .
first.second[foo.index][j].third
     └─────── am ────────┘
```

... and curried function calls:
```
     ........       ..          .
first.second(foo.bar)(foobar.baz).third
     └─────────── am ───────────┘
```

So it turns out that these text objects are pretty handy to select all sorts
of function calls and accesses by index. However, there are a few things that
fall inside undefined behavior. Consult the help pages for more information.

## What this plugin can't do

This plugin does not rely on Vim's syntax items. It therefore works regardless
of whether the file type is correctly set. However, this can lead to
unexpected behavior if the cursor is positioned inside strings, because it
parses its contents as if actual code.

Alpha-numerical characters are fine:
```
             ........
first.second("foobar").third
             └─ am ─┘
```

But spaces create problems:
```
                ......
first.second("  foobar").third
               └──── am ─────┘
```

... as do parenthesis:
```
              .
first.second("((((").third
             └─ am ─┘
```

With the cursor outside of strings, everything is okay, though:
```
     ........        .
first.second("  ((((").third
     └───── am ──────┘
```

If a statement wraps over multiple lines, the plugin will not find code on
other lines than the current one:
```
                 .
     fourth.fifth)
└────── am ──────┘
```

Floats are handled as if digits were letters:
```
 ......
1.34567
 └ am ┘
```
