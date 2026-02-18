;;; obsidian-pcache.el --- Persistent caching for obsidian.el  -*- lexical-binding: t; -*-

;; Copyright (c) 2025 Akinori MUSHA
;;
;; All rights reserved.
;;
;; Redistribution and use in source and binary forms, with or without
;; modification, are permitted provided that the following conditions
;; are met:
;; 1. Redistributions of source code must retain the above copyright
;;    notice, this list of conditions and the following disclaimer.
;; 2. Redistributions in binary form must reproduce the above copyright
;;    notice, this list of conditions and the following disclaimer in the
;;    documentation and/or other materials provided with the distribution.
;;
;; THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
;; ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
;; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
;; ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
;; FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
;; DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
;; OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
;; HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
;; LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
;; OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
;; SUCH DAMAGE.

;; Author: Akinori Musha <knu@iDaemons.org>
;; URL: https://github.com/knu/obsidian-pcache.el
;; Keywords: convenience
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (pcache "0.5.1") (obsidian "1.4.4"))

;;; Commentary:

;; Provides persistent caching for Obsidian vault data using pcache.
;; Automatically saves and restores cache data across Emacs sessions.

;;; Code:

(require 'pcache)
(eval-when-compile
  (require 'obsidian))

;;;; Internal State

(defvar obsidian-pcache--loaded-vaults (make-hash-table :test #'equal)
  "Hash table tracking which vaults have loaded their cache.")

(defvar obsidian-pcache--save-timers (make-hash-table :test #'equal)
  "Hash table of pending save timers for each vault.")

;;;; Configuration

(defcustom obsidian-pcache-save-delay 5
  "Seconds to wait before saving cache after changes."
  :type 'number
  :group 'obsidian)

;;;; Utilities

(defun obsidian-pcache--repo (vault-dir)
  "Return pcache repository object for VAULT-DIR."
  (pcache-repository
   (format "obsidian/%s" (secure-hash 'sha256 (expand-file-name vault-dir)))))

(defun obsidian-pcache--restore (vault-dir)
  "Restore cache for VAULT-DIR unless already loaded."
  (unless (gethash vault-dir obsidian-pcache--loaded-vaults)
    (condition-case err
        (let* ((repo (obsidian-pcache--repo vault-dir))
               (cache (pcache-get repo 'vault-cache)))
          (when cache
            (setq obsidian-vault-cache cache
                  obsidian--aliases-map (pcache-get repo 'aliases-map)
                  obsidian--updated-time (pcache-get repo 'updated-time 0))
            (message "Loaded Obsidian cache for %s" vault-dir))
          (puthash vault-dir t obsidian-pcache--loaded-vaults))
      (error
       (message "Failed to restore Obsidian cache for %s: %s" vault-dir (error-message-string err))))))

(defun obsidian-pcache--save (vault-dir)
  "Serialize current cache for VAULT-DIR to disk."
  (condition-case err
      (when (file-directory-p vault-dir)
        (let ((repo (obsidian-pcache--repo vault-dir)))
          (pcache-put repo 'vault-cache obsidian-vault-cache)
          (pcache-put repo 'aliases-map obsidian--aliases-map)
          (pcache-put repo 'updated-time obsidian--updated-time)
          (message "Saved Obsidian cache for %s" vault-dir)))
    (error
     (message "Failed to save Obsidian cache for %s: %s" vault-dir (error-message-string err))))
  (remhash vault-dir obsidian-pcache--save-timers))

(defun obsidian-pcache--enqueue-save (vault-dir &optional delay)
  "Schedule cache save after DELAY idle seconds (default from customization)."
  (when-let* ((timer (gethash vault-dir obsidian-pcache--save-timers)))
    (cancel-timer timer))
  (puthash vault-dir
           (run-with-idle-timer
            (or delay obsidian-pcache-save-delay) nil
            (lambda () (obsidian-pcache--save vault-dir)))
           obsidian-pcache--save-timers))

;;;; Integration

(defun obsidian-pcache--before-update (&rest _args)
  "Restore obsidian cache before `obsidian-update'."
  (when obsidian-directory
    (obsidian-pcache--restore obsidian-directory)))

(defun obsidian-pcache--after-update (&rest _args)
  "Save obsidian cache after `obsidian-update'."
  (when obsidian-directory
    (obsidian-pcache--enqueue-save obsidian-directory)))

(defun obsidian-pcache--save-all ()
  "Save cache for all loaded vaults and clean up missing directories."
  (let (vaults-to-save vaults-to-remove)
    (maphash (lambda (vault-dir _loaded)
               (if (file-directory-p vault-dir)
                   (push vault-dir vaults-to-save)
                 (push vault-dir vaults-to-remove)))
             obsidian-pcache--loaded-vaults)
    (dolist (vault-dir vaults-to-save)
      (obsidian-pcache--save vault-dir))
    (dolist (vault-dir vaults-to-remove)
      (remhash vault-dir obsidian-pcache--loaded-vaults))
    (when (and obsidian-directory
               (not (gethash obsidian-directory obsidian-pcache--loaded-vaults)))
      (obsidian-pcache--save obsidian-directory))))

;;;; Setup

;;;###autoload
(with-eval-after-load 'obsidian
  (advice-add 'obsidian-update :before #'obsidian-pcache--before-update)
  (advice-add 'obsidian-update :after #'obsidian-pcache--after-update)
  (add-hook 'kill-emacs-hook #'obsidian-pcache--save-all))

(provide 'obsidian-pcache)
;;; obsidian-pcache.el ends here
