;;; related.el --- Switch back and forth between similarly named buffers.

;; Copyright © 2016 Julien Montmartin

;; Author: Julien Montmartin
;; Description: Switch back and forth between similarly named buffers.
;; Created: Fri May 13 2016
;; Version: 0.0.1
;; Keywords: file, buffer, switch, selection, matching, convenience
;; URL: https://bitbucket.org/lyude/related

;; This file is NOT part of GNU Emacs.

;;; License

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
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.

;;; Commentary:

;; Related global minor mode helps you to navigate across similarly
;; named buffers.
;;
;; You might want to add the following code to your .emacs :
;;
;;	(require 'related)
;;	(related-mode)
;;
;; Then use "C-t" to switch to next related buffer, and "C-S-t" to
;; come back. If you are not happy with those key bindings, you might
;; want to try something like this :
;;
;;	(global-set-key (kbd "C-x <up>") 'related-switch-forward)
;;	(global-set-key (kbd "C-x <down>") 'related-switch-backward)
;;
;; Related derive from each buffer an hopefully meaningful "base name"
;; and buffers with same "base name" forms a group. Related helps you
;; to navigate those groups.
;; 
;; For example, buffers visiting the following files :
;;
;;  /path/to/include/foo.h
;;	/path/to/source/foo.c
;;	/path/to/doc/foo.org
;;
;; Would be grouped together (their names reduce to "foo"). Supposing
;; you have dozens of opened buffers, and are working in "foo.h",
;; Related helps you to cycle across "foo" buffers :
;;
;; Cycle "forward" with "C-t" :
;;
;;	foo.h -> foo.c -> foo.org
;;     ^                 |
;;     +-----------------+
;;
;; And cycle "backward" with "C-S-t" :
;;
;;	foo.h <- foo.c <- foo.org
;;     |                 ^
;;     +-----------------+
;;
;; When deriving a "base name" from a buffer path, the following rules
;; are applied :
;;
;;	- Remove directories
;;	- Remove extensions
;;	- Remove non-alpha characters
;;	- Convert remaining characters to lower case
;;
;; Thus "/another/path/to/FOO-123.bar.baz" would also reduce to "foo".

;;; Code:

(require 'cl-lib)

(defun related-buf-path-or-name (buf)
  "Returns the file path associated with buffer BUF. If BUF does not
have a path, its name is returned instead"
  ;; Do not really care about paths. Unique strings are enough.
  ;; Returning name allows buffers such as "*scratch*" to be part of
  ;; the game. Later we do not distinguish between path or name, and
  ;; just say path.
  (or (buffer-file-name buf) (buffer-name buf)))

(defun related-buf< (b1 b2)
  "Compare buf B1 and B2 according to their path name."
  (string<
   (related-buf-path-or-name b1)
   (related-buf-path-or-name b2)))

(defun related-buf= (b1 b2)
  "Test for equality between B1 and B2 according to their path name."
  (string=
   (related-buf-path-or-name b1)
   (related-buf-path-or-name b2)))

(defun related-path-or-name-digest (path)
  "Derive a simplified, hopefully meaningful, name from PATH :

- Remove directories
- Remove extensions
- Remove non-alpha characters
- Convert remaining characters to lower case

Given \"/path/to/Foo2.txt.old\" returns \"foo\".
Given \"*scratch*\" returns \"scratch\"."
  (let (base root)
	(setq base (file-name-nondirectory path))
	(setq root (file-name-sans-extension base))
	(while (not (equal root (file-name-sans-extension root)))
	  (setq root (file-name-sans-extension root)))
	(setq root (replace-regexp-in-string "[^[:alpha:]]" "" root))
	(downcase root)))

(defun related-sorted-buffers (buf)
  "Returns an ordered list of buffers with a name similar to the one
of BUF."
  (let ((digest (related-path-or-name-digest
				 (related-buf-path-or-name buf))))
	(sort
	 (cl-remove-if-not
	  (lambda (b)
		(equal digest (related-path-or-name-digest
					   (related-buf-path-or-name b))))
	  (buffer-list))
	 'related-buf<)))

(defun related-circular-list (l)
  "Append the head of L at the end of L."
  (append l (list (car l))))

(defun related-buffer-switch-list(buf &optional rev)
  "Returns a \"circular\" list of buffers related to BUF. If REV is t
the list is reversed."
  (flet ((dir-f (l) (if rev (reverse l) l)))
	(related-circular-list (dir-f (related-sorted-buffers buf)))))

(defun related-pop-until-buf-rec (buf buffers)
  "Pops BUFFERS \"switch list\" until BUF becomes the head."
  (if (equal 0 (length buffers))
	  nil
	(let ((next (pop buffers)))
	  (if (related-buf= buf next)
		  buffers
		(related-pop-until-buf-rec buf buffers)))))

(defun related-switch-next (&optional rev)
  "Switch to the next related buffer (or previous if REV is t)."
  (let ()
	(setq buf (current-buffer))
	(setq buffers (related-buffer-switch-list buf rev))
	(setq next (car (related-pop-until-buf-rec buf buffers)))
	(if next (switch-to-buffer next))))

(defun related-switch-forward ()
  "Switch to the next related buffer."
  (interactive)
  (related-switch-next))

(defun related-switch-backward ()
  "Switch to the previous related buffer."
  (interactive)
  (related-switch-next t))

(define-minor-mode related-mode
  "Switch back and forth between similarly named buffers."
  :lighter " Rel"
  :global t
  :keymap (let ((map (make-sparse-keymap)))
		(define-key map
		  (kbd "C-t") 'related-switch-forward)
		(define-key map
		  (kbd "C-S-t") 'related-switch-backward)
		map))

(provide 'related)

;;; related.el ends here