;;; wl.el --- Emacs commands for wl command          -*- lexical-binding: t; -*-

;; Copyright (C) 2024  Aaron L. Zeng

;; Author: Aaron L. Zeng <z@bcc32.com>
;; Keywords: convenience, tools
;; Package-Requires: ((emacs "27.1"))
;; URL: https://github.com/bcc32/watch-later
;; Version: 0.1

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;;

;;; Code:

(defvar embark-multitarget-actions)
(defvar embark-transformer-alist)

(require 'json)
(require 'thunk)

(defun wl--list-videos (&optional include-watched)
  "Return list of unwatched videos as plists.

If INCLUDE-WATCHED is non-nil, include watched videos also."
  (let (videos
        (json-object-type 'plist))
    (with-temp-buffer
      (let ((proc (apply #'start-process "wl list" (current-buffer)
                         "wl"
                         (append '("list" "-json")
                                 (unless include-watched '("-watched" "false"))))))
        (while (accept-process-output proc)
          (goto-char (point-min))
          (while (ignore-error end-of-file
                   (save-excursion  ;reset point and try again after more output
                     (push (json-read) videos)
                     (delete-region (point-min) (point))
                     t))))))
    (nreverse videos)))

(defun wl-video--completion-candidates (&optional include-watched)
  "Return list of unwatched videos formatted for completion and searching.

If INCLUDE-WATCHED is non-nil, include watched videos also."
  (let ((result (make-hash-table :test #'equal)))
    (dolist (v (wl--list-videos include-watched) result)
      (puthash
       (format "[%s] %s | %s"
               (plist-get v :video_id)
               (plist-get v :channel_title)
               (plist-get v :video_title))
       v
       result))))

(defun wl-video-completion-table (&optional include-watched)
  "Return completion table of unwatched videos.

If INCLUDE-WATCHED is non-nil, include watched videos also."
  (let ((videos (thunk-delay (wl-video--completion-candidates include-watched))))
    (lambda (string pred action)
      (cond
       ((eq action 'metadata)
        '(metadata (category . wl-video)))
       ((eq action 'get-video)
        (gethash string (thunk-force videos)))
       (t (complete-with-action action (thunk-force videos) string pred))))))

(defun wl-read-video-id (&optional include-watched)
  "Read unwatched video ID, with completion.

If INCLUDE-WATCHED is non-nil, include watched videos also."
  (let* ((videos (wl-video-completion-table include-watched))
         (choice (completing-read "Video: " videos nil t)))
    (plist-get (funcall videos choice nil 'get-video) :video_id)))

;;;###autoload
(defun wl-watch-video (video-ids)
  "Watch the videos whose ids are VIDEO-IDS, a list of strings.

Interactively, prompt for a video."
  (interactive (list (list (wl-read-video-id current-prefix-arg))))
  (let ((orig-process-environment process-environment))
    (with-current-buffer (generate-new-buffer " *wl watch*" t)
      (setq-local process-environment orig-process-environment)
      (push (concat "SSH_CONNECTION=" (getenv "SSH_CONNECTION" (selected-frame)))
            process-environment)
      (let* ((video-id-args (mapcan (lambda (id) (list "-anon" id)) video-ids))
             (ret (apply #'call-process "wl" nil t nil "watch" video-id-args)))
        (if (equal ret 0)
            (kill-buffer)
          (display-buffer (current-buffer))
          (error "Failed to watch videos: %s" video-ids))))))

(with-eval-after-load 'embark
  (add-to-list 'embark-multitarget-actions 'wl-watch-video))

;;;###autoload
(defun wl-remove-video (video-ids)
  "Remove the videos whose ids are VIDEO-IDS, a list of strings.

Interactively, prompt for a video."
  (interactive (list (list (wl-read-video-id current-prefix-arg))))
  (let ((video-id-args (mapcan (lambda (id) (list "-anon" id)) video-ids)))
    (with-current-buffer (generate-new-buffer " *wl remove*" t)
      (let ((ret (apply #'call-process "wl" nil t nil "remove" video-id-args)))
        (if (equal ret 0)
            (kill-buffer)
          (display-buffer (current-buffer))
          (error "Failed to remove videos: %s" video-ids))))))

(with-eval-after-load 'embark
  (add-to-list 'embark-multitarget-actions 'wl-remove-video))

(defun wl--video-embark-transformer (_type target)
  "Return the video ID extracted from completion candidate TARGET.

Appropriate for use as an embark target transformer.  See
`embark-transformer-alist'."
  (cons 'wl-video
        (if (string-match (rx bos "[" (group (= 11 (any "-_" digit alpha))) "]") target)
            (match-string 1 target)
          (error "Target does not match: %S" target))))

(with-eval-after-load 'embark
  (add-to-list 'embark-transformer-alist '(wl-video . wl--video-embark-transformer)))
;; FIXME: this transformer doesn't apply to the default action in
;; embark-collect, the commands should instead apply the transformation to their
;; argument.

(with-eval-after-load 'embark
  (defvar-keymap wl-embark-video-map
    :doc "Keymap for Embark wl-video actions."
    :parent embark-general-map
    "RET" #'wl-watch-video
    "d" #'wl-remove-video
    "w" #'wl-watch-video)
  (defalias 'wl-embark-video-map wl-embark-video-map)
  (add-to-list 'embark-keymap-alist '(wl-video . wl-embark-video-map)))

(provide 'wl)
;;; wl.el ends here
