
;;; Copyright 2009 Gabor Balazs
;;; Licensed under the Apache License, Version 2.0 (the "License");
;;; you may not use this file except in compliance with the License.
;;; You may obtain a copy of the License at
;;;
;;;     http://www.apache.org/licenses/LICENSE-2.0
;;;
;;; Unless required by applicable law or agreed to in writing, software
;;; distributed under the License is distributed on an "AS IS" BASIS,
;;; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;;; See the License for the specific language governing permissions and
;;; limitations under the License.
;;;
;;; $Revision$
;;; $Date$

(in-package :rl-glue-skeleton)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defclass skeleton-environment (rl-glue-codec:environment)
  ((current-state
    :accessor current-state
    :initform 10
    :documentation "Internal environment state."))
  (:documentation "A very thin RL environment skeleton."))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun get-observation (state)
  "Returns an RL observation object containing the STATE."
  (rl-glue-codec:make-observation
   :int-array (rl-glue-codec:make-int-array
               1 :initial-contents (list state))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod rl-glue-codec:env-init ((env skeleton-environment))
  (let ((task-spec (make-instance
                    'rl-glue-utils:task-spec
                    :version "RL-Glue-3.0"
                    :problem-type "episodic"
                    :discount-factor 1.0
                    :int-observations (rl-glue-utils:make-int-range-array
                                       1
                                       :initial-contents
                                       (list (make-instance
                                              'rl-glue-utils:int-range
                                              :min-value 0
                                              :max-value 20)))
                    :int-actions (rl-glue-utils:make-int-range-array
                                  1
                                  :initial-contents
                                  (list (make-instance
                                         'rl-glue-utils:int-range
                                         :min-value 0
                                         :max-value 1)))
                    :rewards (make-instance
                              'rl-glue-utils:float-range
                              :min-value -1.0
                              :max-value  1.0))))
    (rl-glue-utils:to-string task-spec)))

(defmethod rl-glue-codec:env-start ((env skeleton-environment))
  (with-accessors ((current-state current-state)) env
    (setf current-state 10)
    (get-observation current-state)))

(defmethod rl-glue-codec:env-step ((env skeleton-environment) action)
  (with-accessors ((current-state current-state)) env
    (case (aref (rl-glue-codec:int-array action) 0)
      (0 (decf current-state))
      (1 (incf current-state)))
    (let ((reward 0.0) (episode-over nil))
      (when (<= current-state 0)
        (setf current-state 0)
        (setf reward -1.0)
        (setf episode-over t))
      (when (>= current-state 20)
        (setf current-state 20)
        (setf reward 1.0)
        (setf episode-over t))
      (values reward (get-observation current-state) episode-over))))

(defmethod rl-glue-codec:env-cleanup ((env skeleton-environment))
  env)

(defmethod rl-glue-codec:env-message ((env skeleton-environment) input-message)
  (if (string= input-message "What is your name?")
      "My name is skeleton environment, Lisp edition!"
      "I don't know how to respond to your message!"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun start-environment (&rest args)
  "Starts a skeleton environment."
  (apply #'rl-glue-codec:run-env (make-instance 'skeleton-environment) args))
