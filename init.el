;;; init.el --- Uzman's Emacs config  -*- lexical-binding: t; -*-

;;; ------------------------------------------------------------
;;; Basic startup & UI
;;; ------------------------------------------------------------

;; Don't show the default startup screen.
(setq inhibit-startup-message t)

;; Basic UI chrome. Tweak these as you like.
;; (scroll-bar-mode -1)
;; (tool-bar-mode -1)
;; (tooltip-mode -1)
;; (set-fringe-mode 10)

;; Keep the menu bar for now (helpful while learning Emacs).
(menu-bar-mode -1)

;; Handy helper: jump to this config quickly.
(defun open-init-file ()
  "Open the current init file."
  (interactive)
  (find-file user-init-file))

;;; ------------------------------------------------------------
;;; Package management & use-package
;;; ------------------------------------------------------------

(require 'package)

(setq package-archives
      '(("melpa" . "https://melpa.org/packages/")
        ("org"   . "https://orgmode.org/elpa/")
        ("elpa"  . "https://elpa.gnu.org/packages/")))

(package-initialize)

(unless package-archive-contents
  (package-refresh-contents))

;; Bootstrap use-package.
(unless (package-installed-p 'use-package)
  (package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t)

;;; ------------------------------------------------------------
;;; Core editing behaviour
;;; ------------------------------------------------------------

;; Show "match X/Y" during isearch.
(setq isearch-lazy-count t
      lazy-count-prefix-format nil
      lazy-count-suffix-format "   (%s/%s)")

;; Try to keep point in a stable screen position when scrolling.
(setq scroll-preserve-screen-position 'always)

;; Make C-k at beginning of line kill the whole line including newline.
(setq kill-whole-line t)

;; TODO: figure out how to paste over a selected region
(delete-selection-mode 1)

;;; ------------------------------------------------------------
;;; Theme & modeline
;;; ------------------------------------------------------------

(add-to-list 'custom-theme-load-path "~/.emacs.d/themes")
(setq custom-safe-themes t)
(setq doom-themes-enable-italic nil
      doom-themes-enable-bold nil)

;; Theme selection (using doom-themes).
(use-package doom-themes
  :config
  ;; Load theme
  (load-theme 'doom-spacegrey))
  
;; Modern, compact modeline.
(use-package doom-modeline
  :init
  (doom-modeline-mode 1)
  :custom
  (doom-modeline-height 100))

;;; ------------------------------------------------------------
;;; Minibuffer completion & UI (Vertico stack)
;;; ------------------------------------------------------------

;; Persist minibuffer history (M-x, find-file, etc).
(use-package savehist
  :init
  (savehist-mode 1))

;; Vertico: completion UI in the minibuffer.
(use-package vertico
  :init
  (vertico-mode 1))

;; Orderless: flexible matching style (type words in any order).
(use-package orderless
  :init
  (setq completion-styles '(orderless basic)
        completion-category-defaults nil
        ;; Keep file completion sane.
        completion-category-overrides '((file (styles basic partial-completion)))))

;; Marginalia: extra annotations in completion lists.
(use-package marginalia
  :bind (:map minibuffer-local-map
              ("M-A" . marginalia-cycle))  ;; cycle annotation styles
  :init
  (marginalia-mode 1))

;;; ------------------------------------------------------------
;;; Navigation, search & actions (Consult + Embark)
;;; ------------------------------------------------------------

;; Consult: better buffer switcher, search, goto-line, etc.
(use-package consult
  :bind (("C-x b"   . consult-buffer)      ;; switch buffers
         ("C-s"   . consult-line)        ;; search in current buffer
         ("M-s r"   . consult-ripgrep)     ;; ripgrep in project/dir
         ("M-s g"   . consult-grep)        ;; grep in project/dir
         ("M-s i"   . consult-imenu)       ;; symbols in this buffer
         ("M-g g"   . consult-goto-line)   ;; goto line with preview
         ("M-g M-g" . consult-goto-line))) ;; same as above

;; TODO: this is broken... again...
;; Embark: take actions on the thing at point / current candidate.
(use-package embark
  :bind (("C-."   . embark-act)                 ;; context menu for current thing
         ("C-;"   . embark-dwim)                ;; do-what-I-mean
         ("C-h B" . embark-bindings))           ;; show active keybindings
  :init
  ;; Use Embark for prefix help (shows possible keybindings).
  (setq prefix-help-command #'embark-prefix-help-command))

;; Embark-Consult: live previews in Embark collect buffers, etc.
(use-package embark-consult
  :after (embark consult)
  :hook
  (embark-collect-mode . consult-preview-at-point-mode))

;;; ------------------------------------------------------------
;;; Projects & files
;;; ------------------------------------------------------------

(require 'project)

;; Put everything under the standard C-x p prefix.
(with-eval-after-load 'project
  ;; Buffers & files
  (define-key project-prefix-map (kbd "b") #'consult-project-buffer)
  (define-key project-prefix-map (kbd "f") #'project-find-file)

  ;; Compile current project (prompts once per project, then remembers)
  (define-key project-prefix-map (kbd "c") #'project-compile)

  ;; Re-run the last compile from the project root
  (defun my/project-recompile ()
    (interactive)
    (let* ((project (project-current t))
           (default-directory (project-root project)))
      (recompile)))
  (define-key project-prefix-map (kbd "r") #'my/project-recompile)

  ;; Project shell / eshell (nice for running tools in project root)
  (define-key project-prefix-map (kbd "s") #'project-shell)
  (define-key project-prefix-map (kbd "e") #'project-eshell))

(add-to-list 'display-buffer-alist
             '("\\*compilation\\*"
               (display-buffer-reuse-window
                display-buffer-in-side-window)
               (side . right)
               (window-width . 0.45)))

(setq compilation-scroll-output t)

(use-package magit
  :ensure t
  :defer t
  :commands (magit-status magit-blame)
  :init
  ;; Main entrypoint
  (global-set-key (kbd "C-x g") #'magit-status))

;;; ------------------------------------------------------------
;;; Debugging
;;; ------------------------------------------------------------

;; make sure to run: ulimit -c unlimited

(defvar my/gdb-program nil
  "Absolute path to the binary to debug for the current Emacs session.")

(defun my/project-root ()
  "Return current project root or `default-directory' as a fallback."
  (if-let ((proj (project-current)))
      (project-root proj)
    default-directory))

(defun my/gdb-set-program (path)
  "Set `my/gdb-program' to PATH (read interactively)."
  (interactive
   (list
    (expand-file-name
     (read-file-name
      "Binary to debug: "
      (my/project-root) nil t))))
  (setq my/gdb-program path)
  (message "Debug program set to: %s" my/gdb-program))

(defun my/lldb (cmdline)
  "Start plain lldb using CMDLINE (uses last token as binary)."
  (let* ((parts (split-string cmdline " "))
         (binary (car (last parts))))
    (term (format "lldb %s" binary))))

(defun my/gdb-debug ()
  "Start debugger on `my/gdb-program' from the project root.
Uses gdb on Linux and lldb on macOS."
  (interactive)
  (unless my/gdb-program
    (call-interactively #'my/gdb-set-program))
  (let* ((default-directory (my/project-root))
         (bin (shell-quote-argument my/gdb-program)))
    (cond
     ;; -------- Linux → gdb -i=mi --------
     ((eq system-type 'gnu/linux)
      (gdb (format "gdb -i=mi %s" bin)))

     ;; -------- macOS → lldb in term --------
     ((eq system-type 'darwin)
      (my/lldb (format "lldb %s" bin)))

     ;; -------- fallback --------
     (t
      (gdb (format "gdb -i=mi %s" bin))))))

(defun my/find-latest-core (dir)
  "Find newest core file in DIR, or signal a `user-error'."
  (let* ((files (directory-files dir t "core\\([.0-9]*\\)\\'" t)))
    (unless files
      (user-error "No core.* files found in %s" dir))
    (car (sort files
               (lambda (a b)
                 (time-less-p
                  (nth 5 (file-attributes b))
                  (nth 5 (file-attributes a))))))))

(defun my/gdb-debug-latest-core ()
  "Run debugger on `my/gdb-program' and newest core file.
Uses gdb on Linux and lldb on macOS."
  (interactive)
  (unless my/gdb-program
    (call-interactively #'my/gdb-set-program))
  (let* ((default-directory (my/project-root))
         (core (my/find-latest-core default-directory))
         (bin  (shell-quote-argument my/gdb-program))
         (core (shell-quote-argument core)))
    (cond
     ;; -------- Linux → gdb with core --------
     ((eq system-type 'gnu/linux)
      (gdb (format "gdb -i=mi %s %s" bin core)))

     ;; -------- macOS → lldb with -c --------
     ((eq system-type 'darwin)
      (my/lldb (format "lldb %s -c %s" bin core)))

     ;; -------- fallback --------
     (t
      (gdb (format "gdb -i=mi %s %s" bin core))))))

;; keybindings
(global-set-key (kbd "C-c d d") #'my/gdb-debug)
(global-set-key (kbd "C-c d c") #'my/gdb-debug-latest-core)
(global-set-key (kbd "C-c d s") #'my/gdb-set-program)

;; nicer gdb UI when applicable
(setq gdb-many-windows t
      gdb-show-main    t)


;;; ------------------------------------------------------------
;;; Helper tools & discoverability
;;; ------------------------------------------------------------

;; which-key: show possible keybindings after a short delay.
(use-package which-key
  :diminish
  :init
  (which-key-mode 1)
  :config
  (setq which-key-idle-delay 0.5))

;;; ------------------------------------------------------------
;;; Programming languages & LSP
;;; ------------------------------------------------------------

;; C/C++ LSP via Eglot + clangd will go here.
;; Example (to be fleshed out later):
(use-package eglot
  :hook ((c-mode c++-mode c++-ts-mode) . eglot-ensure)
  :config
  ;; Tell eglot to use clangd for C / C++
  (add-to-list 'eglot-server-programs
               '((c-mode c++-mode c++-ts-mode) . ("clangd")))

  ;; Format buffer using clangd (respects project .clang-format)
  (define-key eglot-mode-map (kbd "C-c f") #'eglot-format))

;; Tree-sitter auto setup
(use-package treesit-auto
  :ensure t
  :custom
  ;; Ask before downloading grammars the first time
  (treesit-auto-install 'prompt)
  :config
  ;; Use tree-sitter modes when available
  (treesit-auto-add-to-auto-mode-alist 'all)
  (global-treesit-auto-mode))

(setq major-mode-remap-alist
      '((c-mode   . c-ts-mode)
        (c++-mode . c++-ts-mode)))

(setq treesit-language-source-alist
      '((c   "https://github.com/tree-sitter/tree-sitter-c")
        (cpp "https://github.com/tree-sitter/tree-sitter-cpp")))

;; M-x treesit-install-language-grammar RET cpp RET

;;; ------------------------------------------------------------
;;; Misc
;;; ------------------------------------------------------------

;; macOS clipboard ↔ kill-ring integration, if you want to customise it further.
(defun copy-from-osx ()
  (shell-command-to-string "pbpaste"))

(defun paste-to-osx (text &optional push)
  (let ((process-connection-type nil))
    (let ((proc (start-process "pbcopy" "*Messages*" "pbcopy")))
      (process-send-string proc text)
      (process-send-eof proc))))

(setq interprogram-cut-function 'paste-to-osx)
(setq interprogram-paste-function 'copy-from-osx)

(setq compilation-ask-about-save nil)
(auto-save-visited-mode 1)
(setq auto-save-visited-interval 1)

(setq viper-mode nil)
(setq viper-inhibit-startup-message t)
(require 'viper)
(global-set-key (kbd "M-f") 'viper-forward-word)
(global-set-key (kbd "M-b") 'viper-backward-word)
(global-set-key (kbd "C-v") 'viper-scroll-up)
(global-set-key (kbd "M-v") 'viper-scroll-down)

(electric-pair-mode 1)

;; supporting kitty terminal
(use-package kkp
  :ensure t
  :config
  ;; (setq kkp-alt-modifier 'alt) ;; use this if you want to map the Alt keyboard modifier to Alt in Emacs (and not to Meta)
  (global-kkp-mode +1))

;;; ------------------------------------------------------------
;;; Customisation boilerplate (managed by Custom UI)
;;; ------------------------------------------------------------

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-safe-themes
   '("77fff78cc13a2ff41ad0a8ba2f09e8efd3c7e16be20725606c095f9a19c24d3d"
     "d12b1d9b0498280f60e5ec92e5ecec4b5db5370d05e787bc7cc49eae6fb07bc0"
     "42a6583a45e0f413e3197907aa5acca3293ef33b4d3b388f54fa44435a494739"
     "ff24d14f5f7d355f47d53fd016565ed128bf3af30eb7ce8cae307ee4fe7f3fd0"
     "fffef514346b2a43900e1c7ea2bc7d84cbdd4aa66c1b51946aade4b8d343b55a"
     "d97ac0baa0b67be4f7523795621ea5096939a47e8b46378f79e78846e0e4ad3d"
     "dd4582661a1c6b865a33b89312c97a13a3885dc95992e2e5fc57456b4c545176"
     "0d2c5679b6d087686dcfd4d7e57ed8e8aedcccc7f1a478cd69704c02e4ee36fe"
     "0325a6b5eea7e5febae709dab35ec8648908af12cf2d2b569bedc8da0a3a81c1"
     "d481904809c509641a1a1f1b1eb80b94c58c210145effc2631c1a7f2e4a2fdf4"
     "c07f072a88bed384e51833e09948a8ab7ca88ad0e8b5352334de6d80e502da8c"
     "9d5124bef86c2348d7d4774ca384ae7b6027ff7f6eb3c401378e298ce605f83a"
     "e4a702e262c3e3501dfe25091621fe12cd63c7845221687e36a79e17cf3a67e0"
     "456697e914823ee45365b843c89fbc79191fdbaff471b29aad9dcbe0ee1d5641"
     "7c3d62a64bafb2cc95cd2de70f7e4446de85e40098ad314ba2291fc07501b70c"
     "f4d1b183465f2d29b7a2e9dbe87ccc20598e79738e5d29fc52ec8fb8c576fcfd"
     "7771c8496c10162220af0ca7b7e61459cb42d18c35ce272a63461c0fc1336015"
     "6963de2ec3f8313bb95505f96bf0cf2025e7b07cefdb93e3d2e348720d401425"
     "93011fe35859772a6766df8a4be817add8bfe105246173206478a0706f88b33d"
     "e8ceeba381ba723b59a9abc4961f41583112fc7dc0e886d9fc36fa1dc37b4079"
     "dfb1c8b5bfa040b042b4ef660d0aab48ef2e89ee719a1f24a4629a0c5ed769e8"
     "21d2bf8d4d1df4859ff94422b5e41f6f2eeff14dd12f01428fa3cb4cb50ea0fb"
     "b5fd9c7429d52190235f2383e47d340d7ff769f141cd8f9e7a4629a81abc6b19"
     "921f165deb8030167d44eaa82e85fcef0254b212439b550a9b6c924f281b5695"
     "9e5e0ff3a81344c9b1e6bfc9b3dcf9b96d5ec6a60d8de6d4c762ee9e2121dfb2"
     "f1e8339b04aef8f145dd4782d03499d9d716fdc0361319411ac2efc603249326"
     "aec7b55f2a13307a55517fdf08438863d694550565dee23181d2ebd973ebd6b8"
     "4594d6b9753691142f02e67b8eb0fda7d12f6cc9f1299a49b819312d6addad1d"
     "2f7fa7a92119d9ed63703d12723937e8ba87b6f3876c33d237619ccbd60c96b9"
     "b754d3a03c34cfba9ad7991380d26984ebd0761925773530e24d8dd8b6894738"
     "83550d0386203f010fa42ad1af064a766cfec06fc2f42eb4f2d89ab646f3ac01"
     "4d5d11bfef87416d85673947e3ca3d3d5d985ad57b02a7bb2e32beaf785a100e"
     "1f8bd4db8280d5e7c5e6a12786685a7e0c6733b0e3cf99f839fb211236fb4529"
     "f053f92735d6d238461da8512b9c071a5ce3b9d972501f7a5e6682a90bf29725"
     "38b43b865e2be4fe80a53d945218318d0075c5e01ddf102e9bec6e90d57e2134"
     "8c7e832be864674c220f9a9361c851917a93f921fedb7717b1b5ece47690c098"
     "72d811b0506774df615b4095c16644555bb60eea9305ac046d846b11d548c075"
     "21421f966817fbfea466f10fd38c779b3cde2a7c0328599c1269fbdc4173680d"
     default))
 '(package-selected-packages
   '(consult doom-modeline doom-themes embark embark-consult magit
	     marginalia orderless realgud savehist treesit-auto
	     vertico which-key)))

(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
