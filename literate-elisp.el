;;; literate-elisp.el --- literate program to write elisp codes in org mode  -*- lexical-binding: t; -*-

;; Copyright (C) 2018-2019 Jingtao Xu

;; Author: Jingtao Xu <jingtaozf@gmail.com>
;; Created: 6 Dec 2018
;; Version: 0.1
;; Keywords: lisp docs extensions tools
;; URL: https://github.com/jingtaozf/literate-elisp
;; Package-Requires: ((emacs "24"))

;;; Commentary:

;; This file is automatically generated by function `literate-tangle' from file `literate-elisp.org'.
;; It is not designed to be readable by a human and is generated to load by Emacs directly without library `literate-elisp'.
;; you should read file `literate-elisp.org' to find out the usage and implementation detail of this source file.

;;; Code:

(require 'cl-lib)

(defvar literate-elisp-debug-p nil)

(defvar literate-elisp-org-code-blocks-p nil)

(defun literate-peek (in)
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

(defun literate-next (in)
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

(defun literate-position (in)
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

(defun literate-read-while (in pred)
  "Read and return a string from the input stream, as long as the predicate.
Argument IN: input stream.
Argument PRED: predicate function."
  (let ((chars (list)) ch)
    (while (and (setq ch (literate-peek in))
                (funcall pred ch))
      (push (literate-next in) chars))
    (apply #'string (nreverse chars))))

(defun literate-read-until-end-of-line (in)
  "Skip over a line (move to `end-of-line').
Argument IN: input stream."
  (prog1
    (literate-read-while in (lambda (ch)
                              (not (eq ch ?\n))))
    (literate-next in)))

(defun literate-tangle-p (flag)
  "Tangle current elisp code block or not.
Argument FLAG: flag symbol."
  (cl-case flag
    (no nil)
    (t t)))

(defun literate-read-org-options (options)
  "Read org code block options.
Argument OPTIONS: a string to hold the options."
  (cl-loop for token in (split-string options)
        collect (intern token)))

(defvar literate-elisp-read 'read)

(defun literate-read-datum (in)
  "Read and return a Lisp datum from the input stream.
Argment IN: input stream."
  (let ((ch (literate-peek in)))
    (when literate-elisp-debug-p
      (message "literate-read-datum to character '%c'(position:%s)."
               ch (literate-position in)))
    (condition-case ex
         (cond
           ((not ch)
            (error "End of file during parsing"))
           ((and (not literate-elisp-org-code-blocks-p)
                 (not (eq ch ?\#)))
            (let ((line (literate-read-until-end-of-line in)))
              (when literate-elisp-debug-p
                (message "ignore line %s" line)))
            nil)
           ((eq ch ?\#)
            (literate-next in)
            (literate-read-after-sharpsign in))
           (t (funcall literate-elisp-read in)))
       (invalid-read-syntax
        (when literate-elisp-debug-p
          (message "reach invalid read syntax %s at position %s"
                   ex (literate-position in)))
        (if (equal "#" (second ex))
          ;; maybe this is #+end_src
          (literate-read-after-sharpsign in)
          ;; re-throw this signal because we don't know how to handle it.
          (signal (car ex) (cdr err)))))))

(defvar literate-elisp-begin-src-id "#+BEGIN_SRC elisp")
(defun literate-read-after-sharpsign (in)
  "Read after #.
Argument IN: input stream."
        ;; 1. if it is not inside an elisp syntax
  (cond ((not literate-elisp-org-code-blocks-p)
         ;; 1.1 check if it is `#+begin_src elisp'
         (if (cl-loop for i from 1 below (length literate-elisp-begin-src-id)
                   for c1 = (aref literate-elisp-begin-src-id i)
                   for c2 = (literate-next in)
                   thereis (not (char-equal c1 c2)))
         ;; 1.2. if it is not, continue to use org syntax and ignore this line
           (progn (literate-read-until-end-of-line in)
                  nil)
         ;; 1.3 if it is, read source block options for this code block
           (let ((org-options (literate-read-org-options (literate-read-until-end-of-line in))))
             (when literate-elisp-debug-p
               (message "found org elisp src block, options:%s" org-options))
             (cond ((literate-tangle-p (cl-getf org-options :tangle))
         ;; 1.4 if it should be tangled, switch to elisp syntax context
                    (when literate-elisp-debug-p
                      (message "enter into a elisp code block"))
                    (setf literate-elisp-org-code-blocks-p t)
                    nil)))))
         ;; 1.5 if it should not be tangled, continue to use org syntax and ignore this line
        (t
        ;; 2. if it is inside an elisp syntax
         (let ((c (literate-next in)))
           (when literate-elisp-debug-p
             (message "found #%c inside a org block" c))
           (cl-case c
             ;; 2.1 check if it is ~#+~, which has only legal meaning when it is equal `#+end_src'
             (?\+ 
              (let ((line (literate-read-until-end-of-line in)))
                (when literate-elisp-debug-p
                  (message "found org elisp end block:%s" line)))
             ;; 2.2. if it is, then switch to org mode syntax. 
              (setf literate-elisp-org-code-blocks-p nil)
              nil)
             ;; 2.3 if it is not, then use original elip reader to read the following stream
             (t (funcall literate-elisp-read in)))))))

(defun literate-read-internal (&optional in)
  "A wrapper to follow the behavior of original read function.
Argument IN: input stream."
  (cl-loop for form = (literate-read-datum in)
        if form
          do (cl-return form)
             ;; if original read function return nil, just return it.
        if literate-elisp-org-code-blocks-p
          do (cl-return nil)
             ;; if it reach end of stream.
        if (null (literate-peek in))
          do (cl-return nil)))

(defun literate-read (&optional in)
  "Literate read function.
Argument IN: input stream."
  (if (and load-file-name
           (string-match "\\.org\\'" load-file-name))
    (literate-read-internal in)
    (read in)))

(defun literate-load (path)
  "Literate load function.
Argument PATH: target file to load."
  (let ((load-read-function (symbol-function 'literate-read))
        (literate-elisp-org-code-blocks-p nil))
    (load path)))

(defun literate-batch-load ()
  "Literate load file in `command-line' arguments."
  (or noninteractive
      (signal 'user-error '("This function is only for use in batch mode")))
  (if command-line-args-left
    (literate-load (pop command-line-args-left))
    (error "No argument left for `literate-batch-load'")))


(defun literate-load-file (file)
  "Load the Lisp file named FILE.
Argument FILE: target file path."
  ;; This is a case where .elc and .so/.dll make a lot of sense.
  (interactive (list (read-file-name "Load org file: " nil nil 'lambda)))
  (literate-load (expand-file-name file)))

(defun literate-byte-compile-file (file &optional load)
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
    (fset 'read (symbol-function 'literate-read-internal))
    (unwind-protect
        (byte-compile-file file load)
      (fset 'read original-read))))

(defun literate-elisp-tangle-reader (&optional buf)
  "Tangling codes in one code block.
Arguemnt BUF: source buffer."
  (with-output-to-string
      (with-current-buffer buf
        (when (/= (point) (line-beginning-position))
          ;; if reader still in last line,move it to next line.
          (forward-line 1))
        (loop for line = (buffer-substring-no-properties (line-beginning-position) (line-end-position))
              until (or (eobp) (string-equal (downcase line) "#+end_src"))
              do (loop for c across line
                       do (write-char c))
                 (write-char ?\n)
                 (forward-line 1)))))

(cl-defun literate-tangle (file &key (el-file (concat (file-name-sans-extension file) ".el")) header tail)
  "Literate tangle
Argument FILE: target file"
  (let* ((source-buffer (find-file-noselect file))
         (target-buffer (find-file-noselect el-file))
         (org-path-name (concat (pathname-name file) "." (pathname-type file)))
         (literate-elisp-read 'literate-elisp-tangle-reader)
         (literate-elisp-org-code-blocks-p nil))
    (with-current-buffer target-buffer
      (delete-region (point-min) (point-max))
      (when header
        (insert header "\n"))
      (insert ";; This file is automatically generated by function `literate-tangle' from file `" org-path-name "'.\n"
              ";; It is not designed to be readable by a human and is generated to load by Emacs directly without library `literate-elisp'.\n"
              ";; you should read file `" org-path-name "' to find out the usage and implementation detail of this source file.\n\n"
              ";;; Code:\n\n"))

    (with-current-buffer source-buffer
      (goto-char (point-min))
      (cl-loop for obj = (literate-read-internal source-buffer)
               if obj
               do (with-current-buffer target-buffer
                    (insert obj "\n"))
               until (eobp)))

    (with-current-buffer target-buffer
      (when tail
        (insert "\n" tail))
      (save-buffer)
      (kill-current-buffer))))

 

;; This is a comment line to test empty code block.

(ert-deftest literate-read-org-options ()
  "A spec of function to read org options."
  (should (equal (literate-read-org-options " :tangle yes") '(:tangle yes)))
  (should (equal (literate-read-org-options " :tangle no  ") '(:tangle no)))
  (should (equal (literate-read-org-options ":tangle yes") '(:tangle yes))))


(provide 'literate-elisp)
;;; literate-elisp.el ends here
