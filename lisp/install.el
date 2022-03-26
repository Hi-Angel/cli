;;; install.el --- Install packages  -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Command use to install Emacs packages,
;;
;;   $ eask install [names..]
;;
;;
;;  Initialization options:
;;
;;    [names..]     name of the package to install; else we try to install
;;                  package from current directory by calling function
;;                  `package-install-file'
;;
;;  Effective flags:
;;
;;    [-g, --global] [--development, --dev]
;;

;;; Code:

(load-file (expand-file-name
            "_prepare.el"
            (file-name-directory (nth 1 (member "-scriptload" command-line-args)))))

(eask-load "package")  ; load dist path

(defun eask--package-tar ()
  "Find a possible package tar file."
  (let* ((name (eask-guess-package-name))
         (version (eask-package-get :version))
         (dist (expand-file-name eask-dist-path))
         (tar (expand-file-name (concat name "-" version ".tar") dist)))
    (and (file-exists-p tar) tar)))

(eask-start
  (eask-pkg-init)
  (if-let ((names (eask-args)))
      ;; If package [name..] are specified, we try to install it
      (dolist (name names) (eask-package-install name))
    ;; Else we try to install package from the working directory
    (mapc #'eask-package-install eask-depends-on)
    (when (eask-dev-p) (mapc #'eask-package-install eask-depends-on-dev))
    ;; Start the normal package installation procedure
    (message "Installing %s..." eask-package-file)
    (package-install-file eask-package-file)
    (let ((target (or (eask--package-tar) (expand-file-name "./"))))
      (message "Installing %s..." target)
      (package-install-file target))))

;;; install.el ends here
