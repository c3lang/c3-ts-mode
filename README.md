# c3-ts-mode
This tree-sitter powered Emacs >= 29 major mode provides syntax highlighting, indentation, imenu and which-function support for C3.
It's built against the tree-sitter grammar located at [<https://github.com/c3lang/tree-sitter-c3>](https://github.com/c3lang/tree-sitter-c3).

## Installing

This mode requires Emacs 29 or greater for the built-in tree-sitter support.

### Install the tree-sitter grammar
Add the source url to your `treesit-language-source-alist`.
```elisp
(setq treesit-language-source-alist
  '((c3 "https://github.com/c3lang/tree-sitter-c3")))
```

If you already have a `treesit-language-source-alist`, you can also append to it using:
```elisp
(add-to-list 'treesit-language-source-alist
  '(c3 "https://github.com/c3lang/tree-sitter-c3"))
```

Next, `M-x` run `treesit-install-language-grammar` and enter `c3`. (This requires `cc` to be available on your system.)

A `libtree-sitter-c3.so` should now be built and installed in your emacs directory.

### Install the mode

Clone this repository and add:
```elisp
(add-to-list 'load-path "path/to/c3-ts-mode")
(require 'c3-ts-mode)
```

## Configuration

Set the indent offset using the `c3-ts-mode-indent-offset` variable:
```elisp
(setq c3-ts-mode-indent-offset 2)
```

To enable all highlighting features, you might want to set `treesit-font-lock-level` to 4 (the default is 3):
```elisp
(setq treesit-font-lock-level 4)
```

## Notes
- A special feature is that assignments (and updates via `++`/`--`) are highlighted accurately.
  - If a variable or field is assigned, the variable name is highlighted.
  - If a pointer dereference is assigned, the asterisk is highlighted.
  - If an array index is assigned, the subscript brackets are highlighted (won't be visible with rainbow-delimiters though).
- Indentation is tricky and has a bunch of edge cases - please submit an issue if you find a case where it doesn't work as expected.
