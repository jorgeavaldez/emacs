;; Disable toolbars, menus, and other visual elements for faster startup:
(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)

(setq inhibit-startup-screen t)

;; Load themes early to avoid flickering during startup (you need a built-in theme, though)
;; (load-theme 'modus-operandi t)

;; tweak native compilation settings
(setq native-comp-speed 2)
