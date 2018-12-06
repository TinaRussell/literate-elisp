;;; literate-elisp.el --- literate program to write elisp codes in org mode

;; Copyright (C) 2018-2019 Jingtao Xu

;; Author: Jingtao Xu <jingtaozf@gmail.com>
;; Created: 6 Dec 2018
;; Version: 0.1
;; Keywords: elisp literate org
;; URL: https://github.com/jingtaozf/literate-elisp

;;; Commentary:

;; This file is automatically generated by `literate-tangle' from file `literate-elisp.org'

;;; Code:

(defvar literate-elisp-debug-p nil)

(defvar literate-elisp-org-code-blocks-p nil)

(defun literate-peek
       (in)
  "Return the next character without dropping it from the stream.\nArgument IN: input stream."
  (cond
    ((bufferp in)
     (with-current-buffer in
       (when
           (not
            (eobp))
         (char-after))))
    ((markerp in)
     (with-current-buffer
         (marker-buffer in)
       (when
           (<
            (marker-position in)
            (point-max))
         (char-after in))))
    ((functionp in)
     (let
         ((c
           (funcall in)))
       (when c
         (funcall in c))
       c))))

(defun literate-next
       (in)
  "Given a stream function, return and discard the next character.\nArgument IN: input stream."
  (cond
    ((bufferp in)
     (with-current-buffer in
       (when
           (not
            (eobp))
         (prog1
           (char-after)
           (forward-char 1)))))
    ((markerp in)
     (with-current-buffer
         (marker-buffer in)
       (when
           (<
            (marker-position in)
            (point-max))
         (prog1
           (char-after in)
           (forward-char 1)))))
    ((functionp in)
     (funcall in))))

(defun literate-read-while
       (in pred)
  "Read and return a string from the input stream, as long as the predicate.\nArgument IN: input stream.\nArgument PRED: predicate function."
  (let
      ((chars
        (list))
       ch)
    (while
        (and
          (setq ch
                  (literate-peek in))
          (funcall pred ch))
      (push
        (literate-next in)
        chars))
    (apply #'string
           (nreverse chars))))

(defun literate-skip-to-end-of-line
       (in)
  "Skip over a comment (move to `end-of-line').\nArgument IN: input stream."
  (prog1
    (literate-read-while in
                         (lambda
                             (ch)
                           (not
                            (eq ch 10))))
    (literate-next in)))

(defun literate-tangle-p
       (flag)
  "Tangle current elisp code block or not\nArgument FLAG: flag symbol."
  (case flag
    (no nil)
    (t t)))

(defun literate-read-org-options
       (options)
  "Read org code block options.\nArgument OPTIONS: a string to hold the options."
  (loop for token in
                  (split-string options)
        collect
        (intern token)))

(defun literate-read-datum
       (in)
  "Read and return a Lisp datum from the input stream.\nArgment IN: input stream."
  (let
      ((ch
        (literate-peek in)))
    (cond
      ((not ch)
       (error "End of file during parsing"))
      ((eq ch 10)
       (literate-next in)
       nil)
      ((and
         (not literate-elisp-org-code-blocks-p)
         (not
          (eq ch 35)))
       (let
           ((line
             (literate-skip-to-end-of-line in)))
         (when literate-elisp-debug-p
           (message "ignore line %s" line)))
       nil)
      ((eq ch 35)
       (literate-read-after-sharpsign in))
      (t
       (read in)))))

(defvar literate-elisp-begin-src-id "#+BEGIN_SRC elisp")

(defun literate-read-after-sharpsign
       (in)
  "Read after #.\nArgument IN: input stream."
  (literate-next in)
  (cond
    ((not literate-elisp-org-code-blocks-p)
     (if
         (loop for i from 1 below
                            (length literate-elisp-begin-src-id)
               for c1 =
                      (aref literate-elisp-begin-src-id i)
               for c2 =
                      (literate-next in)
               thereis
               (not
                 (char-equal c1 c2)))
       (progn
         (literate-skip-to-end-of-line in)
         nil)
       (let
           ((org-options
             (literate-read-org-options
              (literate-skip-to-end-of-line in))))
         (when literate-elisp-debug-p
           (message "found org elisp src block, options:%s" org-options))
         (cond
           ((literate-tangle-p
             (getf org-options :tangle))
            (when literate-elisp-debug-p
              (message "enter into a elisp code block"))
            (setf literate-elisp-org-code-blocks-p t)
            nil)))))
    (literate-elisp-org-code-blocks-p
     (let
         ((c
           (literate-next in)))
       (when literate-elisp-debug-p
         (message "found #%c inside a org block" c))
       (case c
         (43
          (let
              ((line
                (literate-skip-to-end-of-line in)))
            (when literate-elisp-debug-p
              (message "found org elisp end block:%s" line)))
          (setf literate-elisp-org-code-blocks-p nil))
         (t
          (read in)))))
    (t
     (read in))))

(defun literate-read
       (&optional in)
  "Literate read function.\nArgument IN: input stream."
  (if
      (and load-file-name
           (string-match "\\.org\\'" load-file-name))
    (literate-read-datum in)
    (read in)))

(defun literate-load
       (path)
  "Literate load function.\nArgument PATH: target file to load."
  (let
      ((load-read-function
        (symbol-function 'literate-read))
       (literate-elisp-org-code-blocks-p nil))
    (load path)))

(defun literate-load-file
       (file)
  "Load the Lisp file named FILE.\nArgument FILE: target file path."
  (interactive
   (list
    (read-file-name "Load org file: " nil nil 'lambda)))
  (literate-load
   (expand-file-name file)))

(defun literate-byte-compile-file
       (file)
  "Byte compile an org file.\nArgument FILE: file to compile.")

(cl-defun literate-tangle
    (file &key
          (el-file
           (concat
            (file-name-sans-extension file)
            ".el"))
          header tail)
  "Literate tangle\nArgument FILE: target file"
  (let*
      ((source-buffer
         (find-file-noselect file))
       (target-buffer
         (find-file-noselect el-file))
       (load-read-function
         (symbol-function 'literate-read))
       (literate-elisp-org-code-blocks-p nil))
    (with-current-buffer target-buffer
      (delete-region
       (point-min)
       (point-max))
      (when header
        (insert header "\n"))
      (insert ";; This file is automatically generated by `literate-tangle' from file `"
              (pathname-name file)
              "."
              (pathname-type file)
              "'\n\n" ";;; Code:\n\n")
      (insert
       (with-output-to-string
           (with-current-buffer source-buffer
             (goto-char
              (point-min))
             (loop for obj =
                           (literate-read-datum source-buffer)
                   if obj do
                     (pp obj)
                     (princ "\n")
                   until
                   (eobp)))))
      (when tail
        (insert "\n" tail))
      (save-buffer)
      (kill-current-buffer))))


(provide 'literate-elisp)
;;; literate-elisp.el ends here
