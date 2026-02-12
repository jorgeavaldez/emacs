;;; init.el --- Bootstrap literate Emacs config -*- lexical-binding: t; -*-

;; Keep this file minimal. Main config lives in config.org.

(require 'org)
(require 'ob-tangle)

(let ((literate-config (expand-file-name "config.org" user-emacs-directory)))
  (if (file-readable-p literate-config)
      (org-babel-load-file literate-config)
    (message "Missing literate config: %s" literate-config)))

;;; init.el ends here
