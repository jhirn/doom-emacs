;;; core.el --- The heart of the beast

;;; Naming conventions:
;;
;;   doom-...   public variables or functions (non-interactive)
;;   doom--...  private anything (non-interactive), not safe for direct use
;;   doom/...   an interactive function
;;   doom:...   an evil operator, motion or command
;;   doom|...   hook function
;;   doom*...   advising functions
;;   ...!       a macro or function that configures DOOM
;;   %...       functions used for in-snippet logic
;;   +...       Any of the above, but part of a module, e.g. +emacs-lisp|init-hook
;;
;; Autoloaded functions are in core/autoload/*.el and modules/*/*/autoload.el or
;; modules/*/*/autoload/*.el.

(defvar doom-version "2.0.2"
  "Current version of DOOM emacs.")

(defvar doom-debug-mode (or (getenv "DEBUG") init-file-debug)
  "If non-nil, all doom functions will be verbose. Set DEBUG=1 in the command
line or use --debug-init to enable this.")

(defvar doom-emacs-dir user-emacs-directory
  "The path to this emacs.d directory.")

(defvar doom-core-dir (concat doom-emacs-dir "core/")
  "Where essential files are stored.")

(defvar doom-modules-dir (concat doom-emacs-dir "modules/")
  "Where configuration modules are stored.")


;; Multi-host directories: I namespace `doom-etc-dir' and `doom-cache-dir' with
;; host names because I use the same (often symlinked) emacs.d across several
;; computers -- often simultaneously. Cache or other temporary files would
;; conflict otherwise.

(defvar doom-local-dir (concat doom-emacs-dir ".local/")
  "Root directory for local Emacs files. Use this as permanent storage for files
that are safe to share across systems (if this config is symlinked across
several computers).")

(defvar doom-etc-dir
  (concat doom-local-dir "@" (system-name) "/etc/")
  "Host-namespaced directory for non-volatile storage. These are not deleted or
tampored with by DOOM functions. Use this for dependencies like servers or
config files that are stable (i.e. it should be unlikely that you need to delete
them if something goes wrong).")

(defvar doom-cache-dir
  (concat doom-local-dir "@" (system-name) "/cache/")
  "Host-namespaced directory for volatile storage. Deleted when
`doom/clean-cache' is called. Use this for transient files that are generated on
the fly like caches and temporary files. Anything that may need to be cleared if
there are problems.")

(defvar doom-packages-dir (concat doom-local-dir "packages/")
  "Where package.el and quelpa plugins (and their caches) are stored.")

(defvar doom-autoload-file
  (concat doom-local-dir "autoloads.el")
  "Location of the autoloads file generated by `doom/reload-autoloads'.")

(defgroup doom nil
  ""
  :group 'emacs)


;;;
;; UTF-8 as the default coding system
(when (fboundp 'set-charset-priority)
  (set-charset-priority 'unicode))     ; pretty
(prefer-coding-system        'utf-8)   ; pretty
(set-terminal-coding-system  'utf-8)   ; pretty
(set-keyboard-coding-system  'utf-8)   ; pretty
(set-selection-coding-system 'utf-8)   ; perdy
(setq locale-coding-system   'utf-8)   ; please
(setq-default buffer-file-coding-system 'utf-8) ; with sugar on top

(setq-default
 ad-redefinition-action 'accept   ; silence advised function warnings
 apropos-do-all t                 ; make `apropos' more useful
 compilation-always-kill t        ; kill compilation process before starting another
 compilation-ask-about-save nil   ; save all buffers on `compile'
 compilation-scroll-output t
 confirm-nonexistent-file-or-buffer t
 enable-recursive-minibuffers nil
 debug-on-error (and (not noninteractive) doom-debug-mode)
 idle-update-delay 2              ; update ui less often
 ;; keep the point out of the minibuffer
 minibuffer-prompt-properties '(read-only t point-entered minibuffer-avoid-prompt face minibuffer-prompt)
 ;; History & backup settings (save nothing, that's what git is for)
 auto-save-default nil
 create-lockfiles nil
 history-length 1000
 make-backup-files nil
 ;; files
 abbrev-file-name             (concat doom-local-dir "abbrev.el")
 auto-save-list-file-name     (concat doom-cache-dir "autosave")
 backup-directory-alist       (list (cons "." (concat doom-cache-dir "backup/")))
 pcache-directory             (concat doom-cache-dir "pcache/")
 server-auth-dir              (concat doom-cache-dir "server/")
 shared-game-score-directory  (concat doom-etc-dir "shared-game-score/")
 tramp-auto-save-directory    (concat doom-cache-dir "tramp-auto-save/")
 tramp-backup-directory-alist backup-directory-alist
 tramp-persistency-file-name  (concat doom-cache-dir "tramp-persistency.el")
 url-cache-directory          (concat doom-cache-dir "url/")
 url-configuration-directory  (concat doom-etc-dir "url/"))

;; move custom defs out of init.el
(setq custom-file (concat doom-etc-dir "custom.el"))
(load custom-file t t)

;; be quiet at startup
(advice-add #'display-startup-echo-area-message :override #'ignore)
(setq inhibit-startup-message t
      inhibit-startup-echo-area-message user-login-name
      initial-major-mode 'fundamental-mode
      initial-scratch-message nil)


;;;
;; Automatic minor modes
(defvar doom-auto-minor-mode-alist '()
  "Alist mapping filename patterns to corresponding minor mode functions, like
`auto-mode-alist'. All elements of this alist are checked, meaning you can
enable multiple minor modes for the same regexp.")

(defun doom|enable-minor-mode-maybe ()
  "Check file name against `doom-auto-minor-mode-alist'."
  (when buffer-file-name
    (let ((name buffer-file-name)
          (remote-id (file-remote-p buffer-file-name))
          (alist doom-auto-minor-mode-alist))
      ;; Remove backup-suffixes from file name.
      (setq name (file-name-sans-versions name))
      ;; Remove remote file name identification.
      (when (and (stringp remote-id)
                 (string-match-p (regexp-quote remote-id) name))
        (setq name (substring name (match-end 0))))
      (while (and alist (caar alist) (cdar alist))
        (if (string-match (caar alist) name)
            (funcall (cdar alist) 1))
        (setq alist (cdr alist))))))

(add-hook 'find-file-hook #'doom|enable-minor-mode-maybe)


;;;
;; Bootstrap
(setq gc-cons-threshold 402653184
      gc-cons-percentage 0.6)

(let (file-name-handler-list)
  (require 'cl-lib)
  (eval-and-compile
    (require 'core-packages (concat doom-core-dir "core-packages")))
  (eval-when-compile
    (doom-initialize))
  (setq load-path (eval-when-compile load-path)
        doom--package-load-path (eval-when-compile doom--package-load-path))

  ;;; Let 'er rip
  (require 'core-lib)
  (require 'core-os) ; consistent behavior across Oses
  (with-demoted-errors "AUTOLOAD ERROR: %s"
    (require 'autoloads doom-autoload-file t))

  (unless noninteractive
    (require 'core-ui)          ; draw me like one of your French editors
    (require 'core-popups)      ; taming sudden yet inevitable windows
    (require 'core-editor)      ; baseline configuration for text editing
    (require 'core-projects)    ; making Emacs project-aware
    (require 'core-keybinds)))  ; centralized keybind system + which-key

(add-hook! 'after-init-hook
  (setq gc-cons-threshold 16777216
        gc-cons-percentage 0.1))

(provide 'core)
;;; core.el ends here
