;;; core/list.el --- List all installed packages  -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Command use to list out installed Emacs packages,
;;
;;   $ eask list
;;
;;
;;  Action options:
;;
;;    [--depth]  dependency level to print
;;

;;; Code:

(let ((dir (file-name-directory (nth 1 (member "-scriptload" command-line-args)))))
  (load (expand-file-name "_prepare.el"
                          (locate-dominating-file dir "_prepare.el"))
        nil t))

(defvar eask--list-pkg-name-offset nil)
(defvar eask--list-pkg-version-offset nil)
(defvar eask--list-pkg-archive-offset nil)

(defun eask--format-s (offset)
  "Format OFFSET."
  (concat " %-" (number-to-string offset) "s "))

(defun eask--align (depth &optional rest)
  "Format string to align starting from the version number.

Argument DEPTH is used to calculate the indentation.  REST is a list of string
for string concatenation."
  (let ((prefix (if (= depth 0) "[+]" "[+]")))
    (concat (spaces-string (* depth 2))  ; indent for depth
            " " prefix
            (eask--format-s (- eask--list-pkg-name-offset (* depth 2)))
            (eask--format-s eask--list-pkg-version-offset)
            (eask--format-s eask--list-pkg-archive-offset)
            rest)))

(defun eask-print-pkg (name depth max-depth pkg-alist)
  "Print NAME package information.

Argument DEPTH is the current dependency nested level.  MAX-DEPTH is the
limitation, so we don't go beyond this deepness.  PKG-ALIST is the archive
contents."
  (when-let*
      ((pkg (assq name pkg-alist))
       (desc (cadr pkg))
       (name (package-desc-name desc))
       (version (package-desc-version desc))
       (version (package-version-join version))
       (archive (or (package-desc-archive desc) ""))
       (summary (package-desc-summary desc)))
    (if (= depth 0)
        (eask-msg (eask--align depth " %-80s") name version archive summary)
      (eask-msg (eask--align depth) name "" "" ""))
    (when-let ((reqs (package-desc-reqs desc))
               ((< depth max-depth)))
      (dolist (req reqs)
        (eask-print-pkg (car req) (1+ depth) max-depth pkg-alist)))))

(defun eask--version-list (pkg-alist)
  "Return a list of versions.

PKG-ALIST is the archive contents."
  (mapcar (lambda (elm)
            (package-version-join (package-desc-version (cadr elm))))
          pkg-alist))

(defun eask--archive-list (pkg-alist)
  "Return list of archives.

PKG-ALIST is the archive contents."
  (mapcar (lambda (elm)
            (or (package-desc-archive (cadr elm)) ""))
          pkg-alist))

(defun eask--list (list pkg-alist &optional depth)
  "List packages.

Argument LIST is the list of packages we want to list.  PKG-ALIST is the archive
contents we want to retrieve package's metadate from.  Optional argument DEPTH
is the deepness of the dependency nested level we want to go."
  (let* ((eask--list-pkg-name-offset (eask-seq-str-max list))
         (version-list (eask--version-list pkg-alist))
         (eask--list-pkg-version-offset (eask-seq-str-max version-list))
         (archive-list (eask--archive-list pkg-alist))
         (eask--list-pkg-archive-offset (eask-seq-str-max archive-list)))
    (dolist (name list)
      (eask-print-pkg name 0 (or depth (eask-depth) 999) pkg-alist))))

(eask-start
  (cond ((eask-all-p)
         (eask-pkg-init)  ; XXX: You must have this!
         (let ((pkg-list (reverse (mapcar #'car package-archive-contents))))
           (eask--list pkg-list package-archive-contents))
         (eask-msg "")
         (eask-info "(Total of %s package%s available)" (length package-archive-contents)
                    (eask--sinr package-archive-contents "" "s")))
        (t
         (eask-defvc< 27 (eask-pkg-init))  ; XXX: remove this after we drop 26.x
         (eask--list package-activated-list package-alist)
         (unless (zerop (length package-activated-list))
           (eask-msg ""))
         (eask-info "(Total of %s package%s installed)"
                    (length package-activated-list)
                    (eask--sinr package-activated-list "" "s")))))

;;; core/list.el ends here
