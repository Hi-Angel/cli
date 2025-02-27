;;; run/script.el --- Run the script  -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Command use to run scripts,
;;
;;   $ eask run script [names..]
;;
;;
;;  Positionals:
;;
;;    [names..]     run the script named <foo>
;;

;;; Code:

(let ((dir (file-name-directory (nth 1 (member "-scriptload" command-line-args)))))
  (load (expand-file-name "_prepare.el"
                          (locate-dominating-file dir "_prepare.el"))
        nil t))

(defconst eask--run-file (expand-file-name "run" eask-homedir)
  "Target file to export the `run' scripts.")

(defun eask--print-scripts ()
  "Print all available scripts."
  (eask-msg "available via `eask run script`")
  (eask-msg "")
  (let* ((keys (mapcar #'car (reverse eask-scripts)))
         (offset (eask-seq-str-max keys))
         (fmt (concat "  %-" (eask-2str offset) "s  %s")))
    (dolist (key keys)
      (eask-msg fmt key (cdr (assoc key eask-scripts))))
    (eask-msg "")
    (eask-info "(Total of %s available script%s)" (length keys)
               (eask--sinr keys "" "s"))))

(defun eask--export-command (command)
  "Export COMMAND instruction."
  (ignore-errors (make-directory eask-homedir t))  ; generate dir `~/.eask/'
  (when eask-is-pkg
    ;; XXX: Due to `MODULE_NOT_FOUND` not found error from vcpkg,
    ;; see https://github.com/vercel/pkg/issues/1356.
    ;;
    ;; We must split up all commands!
    (setq command (eask-s-replace " && " "\n" command)))
  (setq command (concat command " " (eask-rest)))
  (write-region (concat command "\n") nil eask--run-file t))

(defun eask--unmatched-scripts (scripts)
  "Return a list of SCRIPTS that cannot be found in `eask-scripts'."
  (let (unmatched)
    (dolist (script scripts)
      (unless (assoc script eask-scripts)
        (push script unmatched)))
    unmatched))

(eask-start
  ;; Preparation
  (ignore-errors (delete-file eask--run-file))

  ;; Start the task
  (cond
   ((null eask-scripts)
    (eask-info "(No scripts specified)")
    (eask-help "run/script"))
   ((eask-all-p)  ; Run all scripts
    (dolist (data (reverse eask-scripts))
      (eask--export-command (cdr data))))
   ((when-let ((scripts (eask-args)))
      (if-let ((unmatched (eask--unmatched-scripts scripts)))
          (progn  ; if there are unmatched scripts, don't even try to execute
            (eask-info "(Missing script%s: `%s`)"
                       (eask--sinr unmatched "" "s")
                       (mapconcat #'identity unmatched ", "))
            (eask-msg "")
            (eask--print-scripts))
        (dolist (script scripts)
          (let* ((data (assoc script eask-scripts))
                 (name (car data))
                 (command (cdr data)))
            (eask--export-command command)))
        t)))
   (t (eask--print-scripts))))

;;; run/script.el ends here
