;;; literate-elisp.el --- load Emacs Lisp code blocks from Org files  -*- lexical-binding: t; -*-

;; Copyright (C) 2018-2019 Jingtao Xu

;; Author: Jingtao Xu <jingtaozf@gmail.com>
;; Created: 6 Dec 2018
;; Version: 0.1
;; Keywords: lisp docs extensions tools
;; URL: https://github.com/jingtaozf/literate-elisp
;; Package-Requires: ((emacs "26.1"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Literate-elisp is an Emacs Lisp library to provide an easy way to use literate programming in Emacs Lisp.
;; It extends the Emacs load mechanism so Emacs can load Org files as Lisp source files directly.

;;; Code:

;; The code is automatically generated by function `literate-elisp-tangle' from file `literate-elisp.org'.
;; It is not designed to be readable by a human.
;; It is generated to load by Emacs directly without depending on `literate-elisp'.
;; you should read file `literate-elisp.org' to find out the usage and implementation detail of this source file.


(eval-when-compile (require 'cl-macs))
(require 'cl-seq)
(require 'cl-lib)
(require 'org)
(require 'org-src)
(require 'ob-core)
(require 'subr-x)
(require 'nadvice); required by macro `define-advice'

(defvar literate-elisp-debug-p nil)

(defun literate-elisp-debug (format-string &rest args)
  "Print debug messages if `literate-elisp-debug-p' is non-nil.
Argument FORMAT-STRING: same argument of Emacs function `message',
Argument ARGS: same argument of Emacs function `message'."
  (when literate-elisp-debug-p
    (apply 'message format-string args)))

(defvar literate-elisp-org-code-blocks-p nil)

(defvar literate-elisp-begin-src-id "#+BEGIN_SRC")
(defvar literate-elisp-end-src-id "#+END_SRC")
(defvar literate-elisp-lang-ids (list "elisp" "emacs-lisp"))

(defun literate-elisp-peek (in)
  "Return the next character without dropping it from the stream.
Argument IN: input stream."
  (cond ((bufferp in)
         (with-current-buffer in
           (when (not (eobp))
             (char-after))))
        ((markerp in)
         (with-current-buffer (marker-buffer in)
           (when (< (marker-position in) (point-max))
             (char-after in))))
        ((functionp in)
         (let ((c (funcall in)))
           (when c
             (funcall in c))
           c))))

(defun literate-elisp-next (in)
  "Given a stream function, return and discard the next character.
Argument IN: input stream."
  (cond ((bufferp in)
         (with-current-buffer in
           (when (not (eobp))
             (prog1
               (char-after)
               (forward-char 1)))))
        ((markerp in)
         (with-current-buffer (marker-buffer in)
           (when (< (marker-position in) (point-max))
             (prog1
               (char-after in)
               (forward-char 1)))))
        ((functionp in)
         (funcall in))))

(defun literate-elisp-position (in)
  "Return the current position from the stream.
Argument IN: input stream."
  (cond ((bufferp in)
         (with-current-buffer in
           (point)))
        ((markerp in)
         (with-current-buffer (marker-buffer in)
           (marker-position in)))
        ((functionp in)
         "Unknown")))

(defun literate-elisp-read-while (in pred)
  "Read and return a string from the input stream, as long as the predicate.
Argument IN: input stream.
Argument PRED: predicate function."
  (let ((chars (list)) ch)
    (while (and (setq ch (literate-elisp-peek in))
                (funcall pred ch))
      (push (literate-elisp-next in) chars))
    (apply #'string (nreverse chars))))

(defun literate-elisp-read-until-end-of-line (in)
  "Skip over a line (move to `end-of-line').
Argument IN: input stream."
  (prog1
    (literate-elisp-read-while in (lambda (ch)
                              (not (eq ch ?\n))))
    (literate-elisp-next in)))

(defvar literate-elisp-test-p nil)

(defun literate-elisp-load-p (flag)
  "Return non-nil if the current elisp code block should be loaded.
Argument FLAG: the value passed to the :load header argument, as a symbol."
  (pcase flag
    ((or 'yes 'nil) t)
    ('test literate-elisp-test-p)
    ;; these only seem to work on global definitions
    ((pred functionp) (funcall flag))
    ((pred boundp) bar)
    ('no nil)
    (_ nil)))

(defun literate-elisp-read-header-arguments (arguments)
  "Reading org code block header arguments as an alist.
Argument ARGUMENTS: a string to hold the arguments."
  (org-babel-parse-header-arguments (string-trim arguments)))

(defun literate-elisp-get-load-option (in)
  "Read load option from input stream.
Argument IN: input stream."
  (let ((rtn (cdr (assq :load
                        (literate-elisp-read-header-arguments
                         (literate-elisp-read-until-end-of-line in))))))
    (when (stringp rtn)
      (intern rtn))))

(defun literate-elisp-ignore-white-space (in)
  "Skip white space characters.
Argument IN: input stream."
  (while (cl-find (literate-elisp-peek in) '(?\n ?\ ?\t))
    ;; discard current character.
    (literate-elisp-next in)))

(defvar literate-elisp-emacs-read (symbol-function 'read))

(defun literate-elisp-read-datum (in)
  "Read and return a Lisp datum from the input stream.
Argument IN: input stream."

  (literate-elisp-ignore-white-space in)
  (let ((ch (literate-elisp-peek in)))
    (literate-elisp-debug "literate-elisp-read-datum to character '%s'(position:%s)."
                          ch (literate-elisp-position in))

    (cond
      ((not ch)
       (signal 'end-of-file nil))
      ((or (and (not literate-elisp-org-code-blocks-p)
                (not (eq ch ?\#)))
           (eq ch ?\;))
       (let ((line (literate-elisp-read-until-end-of-line in)))
         (literate-elisp-debug "ignore line %s" line))
       nil)
      ((eq ch ?\#)
       (literate-elisp-next in)
       (literate-elisp-read-after-sharpsign in))
      (t
       (literate-elisp-debug "enter into original Emacs read.")
       (funcall literate-elisp-emacs-read in)))))

(defun literate-elisp-read-after-sharpsign (in)
  "Read after #.
Argument IN: input stream."
  ;;     if it is not inside an Emacs Lisp syntax
  (cond ((not literate-elisp-org-code-blocks-p)
         ;; check if it is `#+begin_src'
         (if (or (cl-loop for i from 1 below (length literate-elisp-begin-src-id)
                          for c1 = (aref literate-elisp-begin-src-id i)
                          for c2 = (literate-elisp-next in)
                          with case-fold-search = t
                          thereis (not (char-equal c1 c2)))
                 (while (memq (literate-elisp-peek in) '(?\s ?\t))
                   (literate-elisp-next in)) ; skip tabs and spaces, return nil
                 ;; followed by `elisp' or `emacs-lisp'
                 (cl-loop with lang = ; this inner loop grabs the language specifier
                          (cl-loop while (not (memq (literate-elisp-peek in) '(?\s ?\t ?\n)))
                                   with rtn
                                   collect (literate-elisp-next in) into rtn
                                   finally return (apply 'string rtn))
                          for id in literate-elisp-lang-ids
                          never (string-equal (downcase lang) id)))
           ;; if it is not, continue to use org syntax and ignore this line
           (progn (literate-elisp-read-until-end-of-line in)
                  nil)
           ;; if it is, read source block header arguments for this code block and check if it should be loaded.
           (cond ((literate-elisp-load-p (literate-elisp-get-load-option in))
                  ;; if it should be loaded, switch to Emacs Lisp syntax context
                  (literate-elisp-debug "enter into a Emacs Lisp code block")
                  (setf literate-elisp-org-code-blocks-p t)
                  nil)
                 (t
                  ;; if it should not be loaded, continue to use org syntax and ignore this line
                 nil))))
        (t
        ;; 2. if it is inside an Emacs Lisp syntax
         (let ((c (literate-elisp-next in)))
           (literate-elisp-debug "found #%c inside an org block" c)
           (cl-case c
             ;; check if it is ~#+~, which has only legal meaning when it is equal `#+end_src'
             (?\+
              (let ((line (literate-elisp-read-until-end-of-line in)))
                (literate-elisp-debug "found org Emacs Lisp end block:%s" line))
             ;; if it is, then switch to Org mode syntax.
              (setf literate-elisp-org-code-blocks-p nil)
              nil)
             ;; if it is not, then use original Emacs Lisp reader to read the following stream
             (t (funcall literate-elisp-emacs-read in)))))))

(defun literate-elisp-read-internal (&optional in)
  "A wrapper to follow the behavior of original read function.
Argument IN: input stream."
  (cl-loop for form = (literate-elisp-read-datum in)
        if form
          do (cl-return form)
             ;; if original read function return nil, just return it.
        if literate-elisp-org-code-blocks-p
          do (cl-return nil)
             ;; if it reaches end of stream.
        if (null (literate-elisp-peek in))
          do (cl-return nil)))

(defun literate-elisp-read (&optional in)
  "Literate read function.
Argument IN: input stream."
  (if (and load-file-name
           (string-match "\\.org\\'" load-file-name))
    (literate-elisp-read-internal in)
    (read in)))

(defun literate-elisp-load (path)
  "Literate load function.
Argument PATH: target file to load."
  (let ((load-read-function (symbol-function 'literate-elisp-read))
        (literate-elisp-org-code-blocks-p nil))
    (load path)))

(defun literate-elisp-batch-load ()
  "Literate load file in `command-line' arguments."
  (or noninteractive
      (signal 'user-error '("This function is only for use in batch mode")))
  (if command-line-args-left
    (literate-elisp-load (pop command-line-args-left))
    (error "No argument left for `literate-elisp-batch-load'")))

(defun literate-elisp-load-file (file)
  "Load the Lisp file named FILE.
Argument FILE: target file path."
  ;; This is a case where .elc and .so/.dll make a lot of sense.
  (interactive (list (read-file-name "Load org file: ")))
  (literate-elisp-load (expand-file-name file)))

(defun literate-elisp-byte-compile-file (file &optional load)
  "Byte compile an org file.
Argument FILE: file to compile.
Arguemnt LOAD: load the file after compiling."
  (interactive
   (let ((file buffer-file-name)
	 (file-dir nil))
     (and file
	  (derived-mode-p 'org-mode)
	  (setq file-dir (file-name-directory file)))
     (list (read-file-name (if current-prefix-arg
			     "Byte compile and load file: "
			     "Byte compile file: ")
			   file-dir buffer-file-name nil)
	   current-prefix-arg)))
  (let ((literate-elisp-org-code-blocks-p nil)
        (load-file-name buffer-file-name)
        (original-read (symbol-function 'read)))
    (fset 'read (symbol-function 'literate-elisp-read-internal))
    (unwind-protect
        (byte-compile-file file load)
      (fset 'read original-read))))

(defun literate-elisp-find-library-name (orig-fun &rest args)
  "An advice to make `find-library-name' can recognize org source file.
Argument ORIG-FUN: original function of this advice.
Argument ARGS: the arguments to original advice function."

  (when (string-match "\\(\\.org\\.el\\)" (car args))
    (setf (car args) (replace-match ".org" t t (car args)))
    (literate-elisp-debug "fix literate compiled file in find-library-name :%s" (car args)))
  (apply orig-fun args))
(advice-add 'find-library-name :around #'literate-elisp-find-library-name)

(defun literate-elisp--file-is-org-p (file)
  "Return t if file at FILE is an Org-Mode document, otherwise nil."
  ;; Load FILE into a temporary buffer and see if `set-auto-mode' sets
  ;; it to `org-mode' (or a derivative thereof).
  (with-temp-buffer
    (insert-file-contents file t)
    (delay-mode-hooks (set-auto-mode))
    (derived-mode-p 'org-mode)))

(defmacro literate-elisp--replace-read-maybe (test &rest body)
  "A wrapper which temporarily redefines `read' (if necessary).
If form TEST evaluates to non-nil, then the function slot of `read'
will be temporarily set to that of `literate-elisp-read-internal'
\(by wrapping BODY in a `cl-flet' call)."
  (declare (indent 1)
           (debug (form body)))
  `(cl-letf (((symbol-function 'read)
              (if ,test
                  (symbol-function 'literate-elisp-read-internal)
                ;; `literate-elisp-emacs-read' holds the original function
                ;; definition for `read'.
                literate-elisp-emacs-read)))
     ,@body))

(defun literate-elisp-refs--read-all-buffer-forms (orig-fun buffer)
  "Around advice to make `literate-elisp' package comparible with `elisp-refs'.
Argument ORIG-FUN: the original function.
Argument BUFFER: the buffer."
  (literate-elisp--replace-read-maybe
      (literate-elisp--file-is-org-p
       (with-current-buffer buffer elisp-refs--path))
    (funcall orig-fun buffer)))
(eval-after-load "elisp-refs"
  '(advice-add 'elisp-refs--read-all-buffer-forms :around #'literate-elisp-refs--read-all-buffer-forms))

(defun literate-elisp-refs--loaded-paths (rtn)
  "Filter return advice to prevent it from ignoring Org files.
Argument RTN: rtn."
  (append rtn
          (delete-dups
           (cl-loop for file in (mapcar #'car load-history)
                    if (string-suffix-p ".org" file)
                    collect file
                    ;; handle compiled literate-elisp files
                    else if (and (string-suffix-p ".org.elc" file)
                                 (file-exists-p (substring file 0 -4)))
                    collect (substring file 0 -4)))))
(eval-after-load "elisp-refs"
  '(advice-add 'elisp-refs--loaded-paths :filter-return #'literate-elisp-refs--loaded-paths))

  (with-eval-after-load 'helpful
    (defun literate-elisp-helpful--find-by-macroexpanding (orig-fun &rest args)
      ":around advice for `helpful--find-by-macroexpanding',
  to make the `literate-elisp' package comparible with `helpful'."
      (literate-elisp--replace-read-maybe
          (literate-elisp--file-is-org-p
           (with-current-buffer (car args) buffer-file-name))
        (apply orig-fun args)))
    (advice-add 'helpful--find-by-macroexpanding :around #'literate-elisp-helpful--find-by-macroexpanding))

(defun literate-elisp-tangle-reader (&optional buf)
  "Tangling code in one code block.
Argument BUF: source buffer."
  (with-output-to-string
    (with-current-buffer buf
      (when (not (string-blank-p
                  (buffer-substring (line-beginning-position)
                                    (point))))
        ;; if reader still in last line, move it to next line.
        (forward-line 1))

      (cl-loop for line = (buffer-substring-no-properties (line-beginning-position) (line-end-position))
               until (or (eobp)
                         (string-equal (string-trim (downcase line)) "#+end_src"))
               do (cl-loop for c across line
                           do (write-char c))
               (literate-elisp-debug "tangle Emacs Lisp line %s" line)
               (write-char ?\n)
               (forward-line 1)))))

(cl-defun literate-elisp-tangle (&optional (file (or org-src-source-file-name (buffer-file-name)))
                                 &key (el-file (concat (file-name-sans-extension file) ".el"))
                                header tail
                                test-p)
  "Tangle org file to elisp file.
Argument FILE: target file.
Optional argument EL-FILE .
Optional argument HEADER .
Optional argument TAIL .
Optional argument TEST-P ."
  (interactive)
  (let* ((source-buffer (find-file-noselect file))
         (target-buffer (find-file-noselect el-file))
         (org-path-name (concat (file-name-base file) "." (file-name-extension file)))
         (literate-elisp-emacs-read 'literate-elisp-tangle-reader)
         (literate-elisp-test-p test-p)
         (literate-elisp-org-code-blocks-p nil))
    (with-current-buffer target-buffer
      (delete-region (point-min) (point-max))
      (when header
        (insert header "\n"))
      (insert ";;; Code:\n\n"
              ";; The code is automatically generated by function `literate-elisp-tangle' from file `" org-path-name "'.\n"
              ";; It is not designed to be readable by a human.\n"
              ";; It is generated to load by Emacs directly without depending on `literate-elisp'.\n"
              ";; you should read file `" org-path-name "' to find out the usage and implementation detail of this source file.\n\n"
              "\n"))

    (with-current-buffer source-buffer
      (save-excursion
        (goto-char (point-min))
        (cl-loop for obj = (literate-elisp-read-internal source-buffer)
                 if obj
                 do (with-current-buffer target-buffer
                      (insert obj "\n"))
                 until (eobp))))

    (with-current-buffer target-buffer
      (when tail
        (insert "\n" tail))
      (save-buffer)
      (kill-current-buffer))))

(defcustom literate-elisp-auto-load-org t
  "Whether load and org file from native Emacs load routine."
  :group 'literate-elisp
  :type 'boolean)

(define-advice load
    (:around (fn &rest args) literate-elisp)
  (let ((file (car args)))
    (if (or (string-suffix-p ".org" file)
            (string-suffix-p ".org.elc" file))
      (if literate-elisp-auto-load-org
        (let ((load-read-function (symbol-function 'literate-elisp-read))
              (literate-elisp-org-code-blocks-p nil))
          (apply fn args)))
      (apply fn args))))

(define-advice eval-buffer
    (:around (fn &rest args) literate-elisp)
  (let ((buffer-file (cl-third args)))
    (if (and buffer-file
             (or (string-suffix-p ".org" buffer-file)
                 (string-suffix-p ".org.elc" buffer-file)))
      (if literate-elisp-auto-load-org
        (let ((load-read-function (symbol-function 'literate-elisp-read))
              (literate-elisp-org-code-blocks-p nil))
          (apply fn args)))
      (apply fn args))))

(defvar literate-elisp-default-header-arguments-to-insert
    '((:name :load :property "literate-load" :desc "Source Code Load Type"
       :omit-value "yes"
       :candidates ("yes" "no" "test"))))

(defun literate-elisp-get-header-argument-to-insert (argument-property-name argument-description argument-candidates)
  "Determine the current header argument before inserting a code block.
Argument ARGUMENT-PROPERTY-NAME the Org property name of the header argument.
Argument ARGUMENT-DESCRIPTION the description of the header argument.
Argument ARGUMENT-CANDIDATES the candidates of the header argument."
  (or (org-entry-get (point) argument-property-name t) ;get it from an Org property at current point.
      ;; get it from a candidates list.
      (completing-read argument-description argument-candidates)))

(defvar literate-elisp-language-candidates
    '("lisp" "elisp" "axiom" "spad" "python" "C" "sh" "java" "js" "clojure" "clojurescript" "C++" "css"
      "calc" "asymptote" "dot" "gnuplot" "ledger" "lilypond" "mscgen"
      "octave" "oz" "plantuml" "R" "sass" "screen" "sql" "awk" "ditaa"
      "haskell" "latex" "lisp" "matlab" "ocaml" "org" "perl" "ruby"
      "scheme" "sqlite"))

(defun literate-elisp-get-language-to-insert ()
  "Determine the current literate language before inserting a code block."
  (literate-elisp-get-header-argument-to-insert
   "literate-lang" "Source Code Language: "
   literate-elisp-language-candidates))

(defun literate-elisp-additional-header-to-insert ()
  "Return the additional header arguments string."
  (org-entry-get (point) "literate-header-arguments" t))

(defun literate-elisp-insert-header-argument-p ()
  "Whether to insert additional header arguments."
  (not (string= "no" (org-entry-get (point) "literate-insert-header" t))))

(defun literate-elisp-insert-org-src-block ()
  "Insert the source code block in `org-mode'."
  (interactive)
  (let ((lang (literate-elisp-get-language-to-insert)))
    (when lang
      (insert (format "#+BEGIN_SRC %s" lang))
      (when (literate-elisp-insert-header-argument-p)
        (cl-loop for argument-spec in literate-elisp-default-header-arguments-to-insert
                 for name = (plist-get argument-spec :name)
                 for value = (literate-elisp-get-header-argument-to-insert
                              (plist-get argument-spec :property)
                              (plist-get argument-spec :desc)
                              (plist-get argument-spec :candidates))
                 if (and value (not (equal value (plist-get argument-spec :omit-value))))
                 do (insert (format " %s %s" name value))))
      (let ((additional-arguments (literate-elisp-additional-header-to-insert)))
        (when additional-arguments
          (insert " " additional-arguments)))
      (newline)
      (newline)
      (insert "#+END_SRC\n")
      (forward-line -2))))


(provide 'literate-elisp)
;;; literate-elisp.el ends here
