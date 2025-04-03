;;; c3-ts-mode.el --- Major mode for C3 using tree-sitter -*- lexical-binding: t -*-

;; Author: Christian Buttner <https://github.com/cbuttner>
;; URL: https://github.com/c3lang/c3-ts-mode
;; Keywords: c3 languages tree-sitter
;; Version: 0.9.0
;; Package-Requires : ((emacs "29.1"))

;;; License:

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; if not, see <https://www.gnu.org/licenses>.

;;; Commentary:

;; This tree-sitter powered Emacs 29+ major mode provides syntax highlighting, indentation, imenu and which-function support for C3.
;; It's built against the tree-sitter grammar located at <https://github.com/c3lang/tree-sitter-c3>.

;;; Code:

(require 'treesit)
(require 'c-ts-common)
(require 'compile)

(eval-when-compile (require 'rx))

(declare-function treesit-node-child-by-field-name "treesit.c")
(declare-function treesit-node-type "treesit.c")
(declare-function treesit-node-text "treesit.c")
(declare-function treesit-parser-create "treesit.c")

(defgroup c3-ts nil
  "Major mode for editing C3 files."
  :prefix "c3-ts-"
  :group 'languages)

(defcustom c3-ts-mode-indent-offset 2
  "Number of spaces for each indentation step in `c3-ts-mode'."
  :version "29.1"
  :type 'integer
  :safe 'integerp
  :group 'c3-ts)

(defcustom c3-ts-mode-highlight-variable 't
  "Enable highlighting of variables in `c3-ts-mode'."
  :version "29.1"
  :type 'boolean
  :safe 'booleanp
  :group 'c3-ts)

(defcustom c3-ts-mode-highlight-property 't
  "Enable highlighting of members in `c3-ts-mode'."
  :version "29.1"
  :type 'boolean
  :safe 'booleanp
  :group 'c3-ts)

(defcustom c3-ts-mode-highlight-assignment 't
  "Enable highlighting of assignments in `c3-ts-mode'."
  :version "29.1"
  :type 'boolean
  :safe 'booleanp
  :group 'c3-ts)

(defcustom c3-ts-mode-highlight-punctuation 't
  "Enable highlighting of punctuation in `c3-ts-mode'."
  :version "29.1"
  :type 'boolean
  :safe 'booleanp
  :group 'c3-ts)

(defcustom c3-ts-mode-module-path-face '@font-lock-constant-face
  "The face to use for highlighting module paths in `c3-ts-mode'."
  :version "29.1"
  :type 'symbol
  :group 'c3-ts)

(defcustom c3-ts-mode-assignment-face '@font-lock-variable-name-face
  "The face to use for highlighting assignments in `c3-ts-mode'."
  :version "29.1"
  :type 'symbol
  :group 'c3-ts)

(defcustom c3-ts-mode-hook nil
  "Hook run after entering `c3-ts-mode'."
  :version "29.1"
  :type 'hook
  :group 'c3-ts)

(defvar c3-ts-mode--syntax-table
  (let ((table (make-syntax-table)))
    ;; Adapted from c-ts-mode.el
    (modify-syntax-entry ?_  "_"     table)
    (modify-syntax-entry ?\\ "\\"    table)
    (modify-syntax-entry ?+  "."     table)
    (modify-syntax-entry ?-  "."     table)
    (modify-syntax-entry ?=  "."     table)
    (modify-syntax-entry ?%  "."     table)
    (modify-syntax-entry ?<  ". 1"   table) ; C3: the first character of a comment-start sequence
    (modify-syntax-entry ?>  ". 4"   table) ; C3: the second character of a comment-end sequence
    (modify-syntax-entry ?&  "."     table)
    (modify-syntax-entry ?|  "."     table)
    (modify-syntax-entry ?\' "\""    table)
    (modify-syntax-entry ?`  "\""    table)
    (modify-syntax-entry ?\240 "."   table)
    (modify-syntax-entry ?/ ". 124b" table)
    (modify-syntax-entry ?* ". 23"   table)
    (modify-syntax-entry ?\n "> b"   table)
    (modify-syntax-entry ?\^m "> b"  table)
    table)
  "Syntax table for `c3-ts-mode'.")

(defvar c3-ts-mode--keywords
  ;; From "c3c --list-keywords", without base types
  '("alias"
    "assert"
    "asm"
    "attrdef"
    "bitstruct"
    "break"
    "case"
    "catch"
    "const"
    "continue"
    "default"
    "defer"
    "do"
    "else"
    "enum"
    "extern"
    ;; "false" ;; NOTE Treated as constant
    "faultdef"
    "for"
    "foreach"
    "foreach_r"
    "fn"
    "tlocal"
    "if"
    "inline"
    "import"
    "macro"
    "module"
    "nextcase"
    ;; "null" ;; NOTE Treated as constant
    "interface"
    "return"
    "static"
    "struct"
    "switch"
    ;; "true" ;; NOTE Treated as constant
    "try"
    "typedef"
    "union"
    "var"
    "while"

    "$alignof"
    "$assert"
    "$assignable"
    "$case"
    "$default"
    "$defined"
    "$echo"
    "$else"
    "$embed"
    "$endfor"
    "$endforeach"
    "$endif"
    "$endswitch"
    "$eval"
    "$evaltype"
    "$error"
    "$exec"
    "$extnameof"
    "$feature"
    "$for"
    "$foreach"
    "$if"
    "$include"
    "$is_const"
    "$nameof"
    "$offsetof"
    "$qnameof"
    "$sizeof"
    "$stringify"
    "$switch"
    "$typefrom"
    "$typeof"
    "$vacount"
    "$vatype"
    "$vaconst"
    "$vaarg"
    "$vaexpr"
    "$vasplat"))

(defvar c3-ts-mode--type-properties
  ;; From "c3c --list-type-properties"
  '("alignof"
    "associated"
    "elements"
    "extnameof"
    "inf"
    "is_eq"
    "is_ordered"
    "is_substruct"
    "len"
    "max"
    "membersof"
    "min"
    "nan"
    "inner"
    "kindof"
    "names"
    "nameof"
    "params"
    "parentof"
    "qnameof"
    "returns"
    "sizeof"
    "values"
    ;; Extra token in grammar
    "typeid"))


(defvar c3-ts-mode--operators
  ;; From "c3c --list-operators"
  '("&"
    "!"
    "~"
    "|"
    "^"
    ":"
    ;; ","
    ;; ";"
    "="
    ">"
    "/"
    "."
    ;; "#"
    "<"
    ;; "{"
    ;; "["
    ;; "("
    "-"
    "%"
    "+"
    "?"
    ;; "}"
    ;; "]"
    ;; ")"
    "*"
    ;; "_"
    "&&"
    ;; "->"
    "!!"
    "&="
    "|="
    "^="
    "/="
    ".."
    "?:"
    "=="
    ">="
    "=>"
    "<="
    ;; "[<"
    "-="
    "--"
    "%="
    "*="
    "!="
    "||"
    "+="
    "++"
    ;; ">]"
    "??"
    ;; "::"
    "<<"
    ">>"
    "..."
    "<<="
    ">>="))

(defvar c3-ts-mode--feature-list
  `((comment definition)
    (keyword string type)
    ;; TODO Not clear if assignment should go in level 4 or not (3 is the default level).
    ,(append
      '(builtin attribute escape-sequence literal constant assembly module function doc-comment)
      (when c3-ts-mode-highlight-assignment '(assignment)))
    ,(append
      '(type-property operator bracket)
      (when c3-ts-mode-highlight-punctuation '(punctuation))
      (when c3-ts-mode-highlight-variable '(variable))
      (when c3-ts-mode-highlight-property '(property)))
    ;; (error) ;; Disabled by default
    )
  "`treesit-font-lock-feature-list' for `c3-ts-mode'.")

(defvar c3-ts-mode--font-lock-settings
  ;; NOTE Earlier rules have precedence over later rules
  (treesit-font-lock-rules
   :language 'c3
   :feature 'comment
   '((line_comment) @font-lock-comment-face
     (block_comment) @font-lock-comment-face
     (doc_comment) @font-lock-doc-face)

   :language 'c3
   :feature 'doc-comment
   :override 'append
   `((doc_comment_contract (at_ident) @bold
      (:match ,(rx
                bos
                "@"
                (or
                 "param"
                 "return"
                 "deprecated"
                 "require"
                 "ensure"
                 "pure")
                eos) @bold)))

   :language 'c3
   :feature 'literal
   '((integer_literal) @font-lock-number-face
     (real_literal) @font-lock-number-face
     (char_literal) @font-lock-constant-face
     (bytes_literal) @font-lock-constant-face)

   :language 'c3
   :feature 'string
   '((string_literal) @font-lock-string-face
     (raw_string_literal) @font-lock-string-face)

   :language 'c3
   :feature 'escape-sequence
   :override t
   '((escape_sequence) @font-lock-escape-face)

   :language 'c3
   :feature 'keyword
   `([,@c3-ts-mode--keywords] @font-lock-keyword-face)

   :language 'c3
   :feature 'builtin
   '((builtin) @font-lock-builtin-face)

   :language 'c3
   :feature 'type-property
   `((type_access_expr (access_ident [(ident) "typeid"] @font-lock-constant-face (:match ,(rx-to-string `(: bos (or ,@c3-ts-mode--type-properties) eos)) @font-lock-constant-face))))

   :language 'c3
   :feature 'constant
   '((const_ident) @font-lock-constant-face
     ["true" "false" "null"] @font-lock-constant-face)

   :language 'c3
   :feature 'assembly
   '((asm_instr [(ident) "int"] @font-lock-function-call-face)
     (asm_expr [(ct_ident) (ct_const_ident)] @font-lock-variable-use-face))

   :language 'c3
   :feature 'module
   `((module_resolution (ident) ,c3-ts-mode-module-path-face)
     (module (path_ident (ident) ,c3-ts-mode-module-path-face))
     (import_declaration (path_ident (ident) ,c3-ts-mode-module-path-face)))

   :language 'c3
   :feature 'attribute
   '((attribute name: (_) @font-lock-builtin-face)
     (attrdef_declaration name: (_) @font-lock-builtin-face)
     (call_inline_attributes (at_ident) @font-lock-builtin-face))

   :language 'c3
   :feature 'type
   '((type_ident) @font-lock-type-face
     (ct_type_ident) @font-lock-type-face
     (base_type_name) @font-lock-type-face

     ;; TODO Probably don't want these
     ;; (type_suffix ["[" "[<" ">]" "]"] @font-lock-type-face)
     ;; (type "!" @font-lock-type-face :anchor)
     )

   :language 'c3
   :feature 'definition
   '((func_header name: (_) @font-lock-function-name-face)
     (macro_header name: (_) @font-lock-function-name-face))

   :language 'c3
   :feature 'function
   '((call_expr function: [(ident) (at_ident)] @font-lock-function-call-face)
     (call_expr function: (module_ident_expr ident: (_) @font-lock-function-call-face))
     (call_expr function: (trailing_generic_expr argument: (module_ident_expr ident: (_) @font-lock-function-call-face)))
     (call_expr function: (field_expr field: (access_ident [(ident) (at_ident)] @font-lock-function-call-face))) ; NOTE Ambiguous, could be calling a method or function pointer
     ;; Method on type
     (call_expr function: (type_access_expr field: (access_ident [(ident) (at_ident)] @font-lock-function-call-face))))

   :language 'c3
   :feature 'assignment
   `((assignment_expr left: (ident) ,c3-ts-mode-assignment-face)
     (assignment_expr left: (module_ident_expr (ident) ,c3-ts-mode-assignment-face))
     (assignment_expr left: (field_expr field: (_) ,c3-ts-mode-assignment-face))
     (assignment_expr left: (unary_expr operator: "*" ,c3-ts-mode-assignment-face))
     (assignment_expr left: (subscript_expr ["[" "]"] ,c3-ts-mode-assignment-face))

     (update_expr argument: (ident) ,c3-ts-mode-assignment-face)
     (update_expr argument: (module_ident_expr ident: (ident) ,c3-ts-mode-assignment-face))
     (update_expr argument: (field_expr field: (_) ,c3-ts-mode-assignment-face))
     (update_expr argument: (unary_expr operator: "*" ,c3-ts-mode-assignment-face))
     (update_expr argument: (subscript_expr ["[" "]"] ,c3-ts-mode-assignment-face))

     (unary_expr operator: ["--" "++"] argument: (ident) ,c3-ts-mode-assignment-face)
     (unary_expr operator: ["--" "++"] argument: (module_ident_expr (ident) ,c3-ts-mode-assignment-face))
     (unary_expr operator: ["--" "++"] argument: (field_expr field: (access_ident (ident)) ,c3-ts-mode-assignment-face))
     (unary_expr operator: ["--" "++"] argument: (subscript_expr ["[" "]"] ,c3-ts-mode-assignment-face)))

   :language 'c3
   :feature 'operator
   `(([,@c3-ts-mode--operators]) @font-lock-operator-face)

   :language 'c3
   :feature 'property
   '(;; Member
     (field_expr field: (access_ident (ident) @font-lock-property-use-face))
     (struct_member_declaration (ident) @font-lock-property-name-face)
     (struct_member_declaration (identifier_list (ident) @font-lock-property-name-face))
     (bitstruct_member_declaration (ident) @font-lock-property-name-face)
     (initializer_list (arg (param_path (param_path_element (ident) @font-lock-property-name-face)))))

   :language 'c3
   :feature 'variable
   '([(ident) (ct_ident)] @font-lock-variable-use-face
     ;; Parameter
     (parameter name: (_) @font-lock-variable-name-face)
     (call_invocation (call_arg name: (_) @font-lock-variable-name-face))
     (enum_param_declaration (ident) @font-lock-variable-name-face)
     ;; Declaration
     (global_declaration (ident) @font-lock-variable-name-face)
     (local_decl_after_type name: [(ident) (ct_ident)] @font-lock-variable-name-face)
     (var_decl name: [(ident) (ct_ident)] @font-lock-variable-name-face)
     (try_unwrap (ident) @font-lock-variable-name-face)
     (catch_unwrap (ident) @font-lock-variable-name-face))

   :language 'c3
   :feature 'bracket
   '((["(" ")" "[" "]" "{" "}" "[<" ">]"]) @font-lock-bracket-face)

   :language 'c3
   :feature 'punctuation
   '(([";" "," "::"]) @font-lock-punctuation-face)

   :language 'c3
   :feature 'error
   :override t
   '((ERROR) @font-lock-warning-face))
  "Tree-sitter font-lock settings for `c3-ts-mode'.")

(defvar c3-ts-mode--simple-indent-rules
  `((c3
     ((parent-is "source_file") column-0 0)

     ((node-is "else") parent-bol 0) ;; Also matches $else
     ((node-is "^\\(case\\|ct_case\\|default\\|ct_default\\)_stmt$") parent-bol c3-ts-mode-indent-offset)
     ((node-is "ct_stmt_body") parent-bol c3-ts-mode-indent-offset)
     ((parent-is "ct_stmt_body") standalone-parent 0)
     ((node-is "$endif") parent-bol 0)
     ((node-is "$endfor") parent-bol 0)
     ((node-is "$endswitch") parent-bol 0)

     ((and (parent-is "block_comment_text") c-ts-common-looking-at-star)
      c-ts-common-comment-start-after-first-star -1)

     ;; NOTE This only indents the first line of a doc comment text. This way we preserve identation on subsequent lines, such as list item indentation. TODO Indent to a minimum of 1? Can still ruin formatting
     ((node-is "doc_comment_text") parent-bol 1)
     ((node-is "doc_comment_contract") parent-bol 1)
     ((node-is "*>") parent-bol 0)

     ((node-is "}") standalone-parent 0)
     ((node-is ")") standalone-parent 0)

     ((match "while" "do_stmt" nil nil nil) standalone-parent 0)
     ((match "compound_stmt" "else_part" nil nil nil) standalone-parent 0)

     ;; Attributes
     ((node-is "attributes") standalone-parent c3-ts-mode-indent-offset)
     ((parent-is "attributes") parent 0) ;; Align attributes on same column

     ;; Body/block children
     ((parent-is "enum_body") standalone-parent c3-ts-mode-indent-offset)
     ((parent-is "fault_body") standalone-parent c3-ts-mode-indent-offset)
     ((parent-is "struct_body") standalone-parent c3-ts-mode-indent-offset)
     ((parent-is "bitstruct_body") standalone-parent c3-ts-mode-indent-offset)
     ((parent-is "interface_body") standalone-parent c3-ts-mode-indent-offset)
     ((parent-is "macro_func_body") standalone-parent c3-ts-mode-indent-offset)
     ((parent-is "implies_body") standalone-parent c3-ts-mode-indent-offset)

     ((parent-is "compound_stmt") standalone-parent c3-ts-mode-indent-offset)
     ((parent-is "initializer_list") standalone-parent c3-ts-mode-indent-offset)
     ((parent-is "case_stmt") standalone-parent c3-ts-mode-indent-offset)
     ((parent-is "default_stmt") standalone-parent c3-ts-mode-indent-offset)

     ;; if/switch/for/while/defer with block
     ((match "compound_stmt" "\\(if\\|switch\\|for\\|foreach\\|while\\|do\\|defer\\)_stmt" nil nil nil) standalone-parent 0)

     ;; for/while/defer without block
     ((parent-is "\\(for\\|foreach\\|while\\|defer\\)_stmt") standalone-parent c3-ts-mode-indent-offset)

     ;; Body not handled so far
     ((field-is "body") standalone-parent 0)
     ((field-is "lambda_body") standalone-parent 0)

     ;; Trailing macro block
     ((match "compound_stmt" nil "trailing" nil nil) parent 0)

     ((match nil "field_expr" "field" nil nil) parent-bol c3-ts-mode-indent-offset)
     ((n-p-gp "." "field_expr" nil) parent-bol c3-ts-mode-indent-offset) ;; Field access beginning with "."
     ((match nil "type_access_expr" "field" nil nil) parent-bol c3-ts-mode-indent-offset)
     ((match nil "assignment_expr" "right" nil nil) parent-bol c3-ts-mode-indent-offset)
     ((match nil "const_declaration" "right" nil nil) parent-bol c3-ts-mode-indent-offset)
     ((match nil "global_declaration" "right" nil nil) parent-bol c3-ts-mode-indent-offset)

     ;; Multi line declarations
     ((parent-is "identifier_list") parent 0)
     ((parent-is "multi_declaration") grand-parent c3-ts-mode-indent-offset)
     ((parent-is "local_decl_after_type") parent-bol c3-ts-mode-indent-offset)

     ((parent-is "for_cond") parent 1)
     ((parent-is "foreach_cond") parent 1)
     ((parent-is "paren_cond") parent 1)
     ((parent-is "catch_unwrap_list") parent 0)
     ((parent-is "comma_decl_or_expr") parent 0)

     ;; First parameter/argument
     ((match "^\\(call_\\)?arg\\|parameter\\|enum_param_declaration\\|trailing_block_param\\|attr_param$" nil nil 1 1) parent-bol c3-ts-mode-indent-offset)
     ;; Subsequent parameters/arguments
     ((match "^\\(call_\\)?arg\\|parameter\\|enum_param_declaration\\|trailing_block_param\\|attr_param$" nil nil 2 nil) (nth-sibling 1) 0)

     ;; String/bytes literals
     ((node-is "raw_string_literal") no-indent)
     ((match "string_literal" "string_expr" nil 0 0) parent 0)
     ((match "string_literal" "string_expr"  nil 1 nil) (nth-sibling 0) 0)
     ((match "bytes_literal" "bytes_expr" nil 0 0) parent 0)
     ((match "bytes_literal" "bytes_expr"  nil 1 nil) (nth-sibling 0) 0)

     ((parent-is "paren") parent 1)
     ((parent-is "binary") parent 0)
     ((parent-is "range") parent 0)
     ((parent-is "elvis_orelse") parent 0)
     ((parent-is "ternary") parent c3-ts-mode-indent-offset)
     ((parent-is "subscript") parent c3-ts-mode-indent-offset)
     ((parent-is "update") parent c3-ts-mode-indent-offset)
     ((parent-is "call") parent c3-ts-mode-indent-offset)
     ((parent-is "cast") parent c3-ts-mode-indent-offset)

     ((parent-is "func_declaration") standalone-parent 0)
     ((parent-is "func_header") standalone-parent 0)
     ((parent-is "macro_declaration") standalone-parent 0)
     ((parent-is "macro_header") standalone-parent 0)

     ((node-is "initializer_list") parent 0)

     ;; ((parent-is "ERROR") no-indent 0)
     )))

(defun c3-ts-mode--defun-name (node)
  "Return the name of the defun NODE."
  (let ()
    (treesit-node-text
     (treesit-node-child-by-field-name
      (pcase (treesit-node-type node)
        ("func_definition" (treesit-node-child node 1))
        ("macro_declaration" (treesit-node-child node 1))
        (_ node))
      "name")
     t)))


;;;###autoload
(define-derived-mode c3-ts-mode prog-mode "C3"
  "Major mode for editing C3 files, powered by tree-sitter."
  :group 'c3-ts
  :syntax-table c3-ts-mode--syntax-table

  ;; Comment
  (c-ts-common-comment-setup)

  ;; Electric
  (setq-local electric-indent-chars
              (append "{}():;," electric-indent-chars))

  (when (treesit-ready-p 'c3)
    (treesit-parser-create 'c3)

    ;; Font-lock
    (setq-local treesit-font-lock-settings c3-ts-mode--font-lock-settings)
    (setq-local treesit-font-lock-feature-list c3-ts-mode--feature-list)

    ;; Indent
    (setq-local treesit-simple-indent-rules c3-ts-mode--simple-indent-rules)

    ;; Navigation
    (setq-local treesit-defun-name-function #'c3-ts-mode--defun-name)
    (setq-local treesit-defun-type-regexp
                (rx bos
                    (or "struct_declaration"
                        "bitstruct_declaration"
                        "enum_declaration"
                        "interface_declaration"
                        "func_definition"
                        "macro_declaration"
                        "const_declaration"
                        "alias_declaration"
                        "typedef_declaration"
                        "faultdef_declaration"
                        "attrdef_declaration")
                    eos))

    ;; Imenu
    (setq-local treesit-simple-imenu-settings
                `(("Struct" "\\`struct_declaration\\'" nil nil)
                  ("Bitstruct" "\\`bitstruct_declaration\\'" nil nil)
                  ("Enum" "\\`enum_declaration\\'" nil nil)
                  ("Interface" "\\`interface_declaration\\'" nil nil)
                  ("Function" "\\`func_definition\\'" nil nil)
                  ("Macro" "\\`macro_declaration\\'" nil nil)
                  ("Const" "\\`const_declaration\\'" nil nil)
                  ("Alias" "\\`alias_declaration\\'" nil nil)
                  ("Type" "\\`typedef_declaration\\'" nil nil)
                  ("Fault" "\\`faultdef_declaration\\'" nil nil)
                  ("Attribute" "\\`attrdef_declaration\\'" nil nil)))

    ;; Which-function
    (setq-local which-func-functions (treesit-defun-at-point))

    (treesit-major-mode-setup)))

(when (treesit-ready-p 'c3)
  (add-to-list 'auto-mode-alist '("\\.c3\\'" . c3-ts-mode))
  (add-to-list 'auto-mode-alist '("\\.c3i\\'" . c3-ts-mode))
  (add-to-list 'auto-mode-alist '("\\.c3t\\'" . c3-ts-mode)))

(eval-after-load 'compile
  (lambda()
    (add-to-list 'compilation-error-regexp-alist-alist
                 '(c3
                   "^(\\([^:]*\\):\\([0-9]+\\):\\([0-9]+\\)) \\(Warning\\)?.*$"
                   1 2 3 (4)))
    (add-to-list 'compilation-error-regexp-alist 'c3)))

(provide 'c3-ts-mode)


;;; c3-ts-mode.el ends here
