# c3-ts-mode
This tree-sitter powered Emacs >= 29 major mode provides syntax highlighting, indentation, imenu and which-function support for C3.
It's built against the tree-sitter grammar located at <https://github.com/c3lang/tree-sitter-c3>.

⚠️ Active development. **If you're updating, please do `M-x treesit-install-language-grammar RET c3 RET` to update the tree-sitter grammar too.**

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

Next, run `M-x treesit-install-language-grammar RET c3 RET`. (This requires `cc` to be available on your system.)

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

The default face for module paths is `font-lock-constant-face`. Override it by setting `c3-ts-mode-module-path-face`. The face name must be prefixed with `@`:
```elisp
(setq c3-ts-mode-module-path-face '@font-lock-some-face-here)
```

The default face for assignments (see [Notes](#notes)) is `font-lock-variable-name-face`. Override it by setting `c3-ts-mode-assignment-face`. The face name must be prefixed with `@`:
```elisp
(setq c3-ts-mode-assignment-face '@font-lock-some-face-here)
```

Further options:
```elisp
;; Disable highlighting of variables
(setq c3-ts-mode-highlight-variable nil)
;; Disable highlighting of members
(setq c3-ts-mode-highlight-property nil)
;; Disable highlighting of punctuation
(setq c3-ts-mode-highlight-punctuation nil)
;; Disable highlighting of assignments
(setq c3-ts-mode-highlight-assignment nil)
```

## Notes
- A special feature is that assignments (and updates via `++`/`--`) are highlighted accurately.
  - If a variable or field is assigned, the variable name is highlighted.
  - If a pointer dereference is assigned, the asterisk is highlighted.
  - If an array element is assigned, the subscript brackets are highlighted.
  - You can configure this feature using `c3-ts-mode-highlight-assignment` and `c3-ts-mode-assignment-face`.
- If punctuation is enabled (`treesit-font-lock-level` is `4` and `c3-ts-mode-highlight-punctuation` is `'t`), make sure both `font-lock-punctuation-face` and `font-lock-brackets-face` is defined in your theme.
- Indentation is tricky and has a bunch of edge cases - please submit an issue if you find a case where it doesn't work as expected.
