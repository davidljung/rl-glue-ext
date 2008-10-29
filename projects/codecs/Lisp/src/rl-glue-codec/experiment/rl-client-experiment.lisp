
;;; Copyright 2008 Gabor Balazs
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

(in-package #:org.rl-community.rl-glue-codec)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Experiment client interface.

(defclass experiment ()
  ((exp-socket
    :accessor exp-socket
    :documentation "Socket for the experiment server.")
   (exp-buffer
    :accessor exp-buffer
    :initform (make-buffer)
    :documentation "Buffer used for network communication."))
  (:documentation "The RL-Glue experiment."))

(defun rl-init (exp
                &key
                (host +k-localhost+)
                (port +k-default-port+)
                (max-retry nil)
                (retry-timeout +k-retry-timeout+))
  "DESCRIPTION:
    This initializes everything, passing the environment's task specification
    to the agent. This should be called at the beginning of every trial.
    The rl-init function first connects the EXP to RL-Glue on HOST and PORT.
    If the attempt is refused, it is tried again MAX-RETRY times, waiting for
    RETRY-TIMEOUT second between them.

PARAMETERS:
    exp           : experiment in use [rl-glue:experiment]
    host          : host name or address [string]
                    (key parameter, default is rl-glue:+k-localhost+)
    port          : port number [0 <= integer <= 65535]
                    (key parameter, default is rl-glue:+k-default-port+)
    max-retry     : maximum number of connection trials [nil or 0 < integer]
                    (key parameter, default is nil)
    retry-timeout : duration in seconds waited between retries [0 <= integer]
                    (key parameter, default is rl-glue:+k-retry-timeout+)
RETURNS:
    task specification [string]"
  (declare #.*optimize-settings*)
  (forced-format "RL-Glue Lisp Experiment Codec Version ~a, Build ~a~%"
                 (get-codec-version) (get-svn-codec-version))
  (with-accessors ((socket exp-socket) (buffer exp-buffer)) exp
    (setf socket (rl-wait-for-connection host
                                         port
                                         max-retry
                                         retry-timeout))
    (buffer-clear buffer)
    (rl-send-buffer socket buffer +k-experiment-connection+)
    (buffer-clear buffer)
    (rl-send-buffer socket buffer +k-rl-init+)
    (buffer-clear buffer)
    (assert (= +k-rl-init+
               (the fixnum (rl-recv-buffer socket buffer))))
    (rl-read-task-spec buffer)))

(defun rl-start (exp)
  "DESCRIPTION:
    Do the first step of a run or episode. The action is saved in
    the upcoming-action slot so that it can be used on the next step.

PARAMETERS:
    exp : experiment in use [rl-glue:experiment]

RETURNS:
    first observation [rl-glue:observation]
    first action [rl-glue:action]"
  (declare #.*optimize-settings*)
  (with-accessors ((socket exp-socket) (buffer exp-buffer)) exp
    (buffer-clear buffer)
    (rl-send-buffer socket buffer +k-rl-start+)
    (buffer-clear buffer)
    (assert (= +k-rl-start+
               (the fixnum (rl-recv-buffer socket buffer))))
    (let ((observation (rl-read-observation buffer))
          (action (rl-read-action buffer)))
      (values observation action))))

(defun rl-step (exp)
  "DESCRIPTION:
    Take one step. rl-step uses the saved action and saves the returned
    action for the next step. The action returned from one call must be
    used in the next, so it is better to handle this implicitly so that
    the user doesn't have to keep track of the action. If the
    end-of-episode observation occurs, then no action is returned.

PARAMETERS:
    exp : experiment in use [rl-glue:experiment]

RETURNS:
    reward of the step [double-float]
    observation after the step [rl-glue:observation]
    terminal flag after the step [boolean]
    next action (nil on terminal state) [rl-glue:action]"
  (declare #.*optimize-settings*)
  (with-accessors ((socket exp-socket) (buffer exp-buffer)) exp
    (buffer-clear buffer)
    (rl-send-buffer socket buffer +k-rl-step+)
    (buffer-clear buffer)
    (assert (= +k-rl-step+
               (the fixnum (rl-recv-buffer socket buffer))))
    (let ((terminal (rl-read-terminal buffer))
          (reward (rl-read-reward buffer))
          (obs (rl-read-observation buffer))
          (action (rl-read-action buffer)))
      (values reward obs terminal action))))

(defun rl-cleanup (exp)
  "DESCRIPTION:
    Provides an opportunity to reclaim resources allocated by rl-init.

PARAMETERS:
    exp : experiment in use [rl-glue:experiment]

RETURNS:
    used experiment [rl-glue:experiment]"
  (declare #.*optimize-settings*)
  (with-accessors ((socket exp-socket) (buffer exp-buffer)) exp
    (buffer-clear buffer)
    (rl-send-buffer socket buffer +k-rl-cleanup+)
    (buffer-clear buffer)
    (assert (= +k-rl-cleanup+
               (the fixnum (rl-recv-buffer socket buffer))))
    (usocket:socket-close socket))
  exp)

(defun rl-return (exp)
  "DESCRIPTION:
    Return the cumulative total reward of the current or just completed episode. The
    collection of all the rewards received in an episode (the return) is done within
    rl-return however, any discounting of rewards must be done inside the environment
    or agent.

PARAMETERS:
    exp : experiment in use [rl-glue:experiment]

RETURNS:
    cummulated total reward [double-float]"
  (declare #.*optimize-settings*)
  (with-accessors ((socket exp-socket) (buffer exp-buffer)) exp
    (buffer-clear buffer)
    (rl-send-buffer socket buffer +k-rl-return+)
    (buffer-clear buffer)
    (assert (= +k-rl-return+
               (the fixnum (rl-recv-buffer socket buffer))))
    (rl-read-reward buffer)))

(defun rl-num-steps (exp)
  "DESCRIPTION:
    Return the number of steps elapsed in the current or just completed episode.

PARAMETERS:
    exp : experiment in use [rl-glue:experiment]

RETURNS:
    number of steps [0 <= integer]"
  (declare #.*optimize-settings*)
  (with-accessors ((socket exp-socket) (buffer exp-buffer)) exp
    (buffer-clear buffer)
    (rl-send-buffer socket buffer +k-rl-numsteps+)
    (buffer-clear buffer)
    (assert (= +k-rl-numsteps+
               (the fixnum (rl-recv-buffer socket buffer))))
    (buffer-read-int buffer)))

(defun rl-num-episodes (exp)
  "DESCRIPTION:
    Return the number of episodes finished after rl-init.

PARAMETERS:
    exp : experiment in use [rl-glue:experiment]

RETURNS:
    number of episodes [0 <= integer]"
  (declare #.*optimize-settings*)
  (with-accessors ((socket exp-socket) (buffer exp-buffer)) exp
    (buffer-clear buffer)
    (rl-send-buffer socket buffer +k-rl-numepisodes+)
    (buffer-clear buffer)
    (assert (= +k-rl-numepisodes+
               (the fixnum (rl-recv-buffer socket buffer))))
    (buffer-read-int buffer)))

(defun rl-episode (exp &optional (max-num-steps 0))
  "DESCRIPTION:
    Do one episode until a termination observation occurs or until steps have
    elapsed, whichever comes first. As you might imagine, this is done by
    calling rl-start, then rl-step until the terminal observation occurs. If
    max-num-steps is set to 0, it is taken to be the case where there is no
    limitation on the number of steps taken and rl-episode will continue until
    a termination observation occurs. If no terminal observation is reached
    before max-num-steps is reached, the agent does not call agent-end, it
    simply stops.

PARAMETERS:
    exp           : experiment in use [rl-glue:experiment]
    max-num-steps : maximum number of steps [0 < integer]
                    [optional parameter, default is no limit]
RETURNS:
    terminal flag after the step [boolean]"
  (declare #.*optimize-settings*)
  (with-accessors ((socket exp-socket) (buffer exp-buffer)) exp
    (buffer-clear buffer)
    (buffer-write-int max-num-steps buffer)
    (rl-send-buffer socket buffer +k-rl-episode+)
    (buffer-clear buffer)
    (assert (= +k-rl-episode+
               (the fixnum (rl-recv-buffer socket buffer))))
    (rl-read-terminal buffer)))

(defun rl-save-state (exp)
  "DESCRIPTION:
    Provides an opportunity to extract the state key from the environment
    (see env-save-state for details).

PARAMETERS:
    exp : experiment in use [rl-glue:experiment]

RETURNS:
    state key [rl-glue:state-key]"
  (declare #.*optimize-settings*)
  (with-accessors ((socket exp-socket) (buffer exp-buffer)) exp
    (buffer-clear buffer)
    (rl-send-buffer socket buffer +k-rl-save-state+)
    (buffer-clear buffer)
    (assert (= +k-rl-save-state+
               (the fixnum (rl-recv-buffer socket buffer))))
    (rl-read-state-key buffer)))

(defun rl-load-state (exp state-key)
  "DESCRIPTION:
    Provides an opportunity to reset the state (see env-load-state for details).

PARAMETERS:
    exp       : experiment in use [rl-glue:experiment]
    state-key : state key to send [rl-glue:state-key]

RETURNS:
    state key has been set [rl-glue:state-key]"
  (declare #.*optimize-settings*)
  (with-accessors ((socket exp-socket) (buffer exp-buffer)) exp
    (buffer-clear buffer)
    (rl-write-state-key state-key buffer)
    (rl-send-buffer socket buffer +k-rl-load-state+)
    (buffer-clear buffer)
    (assert (= +k-rl-load-state+
               (the fixnum (rl-recv-buffer socket buffer)))))
  state-key)

(defun rl-save-random-seed (exp)
  "DESCRIPTION:
    Provides an opportunity to extract the random seed key from the environment
    (see env-save-random-seed for details).

PARAMETERS:
    exp : experiment in use [rl-glue:experiment]

RETURNS:
    random seed key [rl-glue:random-seed-key]"
  (declare #.*optimize-settings*)
  (with-accessors ((socket exp-socket) (buffer exp-buffer)) exp
    (buffer-clear buffer)
    (rl-send-buffer socket buffer +k-rl-save-random-seed+)
    (buffer-clear buffer)
    (assert (= +k-rl-save-random-seed+
               (the fixnum (rl-recv-buffer socket buffer))))
    (rl-read-random-seed-key buffer)))

(defun rl-load-random-seed (exp random-seed-key)
  "DESCRIPTION:
    Provides an opportunity to reset the random seed key
    (see env-load-random-seed for details).

PARAMETERS:
    exp             : experiment in use [rl-glue:experiment]
    random-seed-key : random seed key to send [rl-glue:random-seed-key]

RETURNS:
    random seed key has been set [rl-glue:random-seed-key]"
  (declare #.*optimize-settings*)
  (with-accessors ((socket exp-socket) (buffer exp-buffer)) exp
    (buffer-clear buffer)
    (rl-write-random-seed-key random-seed-key buffer)
    (rl-send-buffer socket buffer +k-rl-load-random-seed+)
    (buffer-clear buffer)
    (assert (= +k-rl-load-random-seed+
               (the fixnum (rl-recv-buffer socket buffer)))))
  random-seed-key)

(defun rl-agent-message (exp message)
  "DESCRIPTION:
     This message passes the input string to the agent and returns the
     reply string given by the agent. See agent-message for more details.

PARAMETERS:
    exp     : experiment in use [rl-glue:experiment]
    message : message to send [string]

RETURNS:
    recieved message [string]"
  (declare #.*optimize-settings*)
  (with-accessors ((socket exp-socket) (buffer exp-buffer)) exp
    (buffer-clear buffer)
    (rl-write-message message buffer)
    (rl-send-buffer socket buffer +k-rl-agent-message+)
    (buffer-clear buffer)
    (assert (= +k-rl-agent-message+
               (the fixnum (rl-recv-buffer socket buffer))))
    (rl-read-message buffer)))

(defun rl-env-message (exp message)
  "DESCRIPTION:
    This message passes the input string to the environment and returns the 
    reply string given by the environment. See env-message for more details.

PARAMETERS:
    exp     : experiment in use [rl-glue:experiment]
    message : message to send [string]

RETURNS:
    recieved message [string]"
  (declare #.*optimize-settings*)
  (with-accessors ((socket exp-socket) (buffer exp-buffer)) exp
    (buffer-clear buffer)
    (rl-write-message message buffer)
    (rl-send-buffer socket buffer +k-rl-env-message+)
    (buffer-clear buffer)
    (assert (= +k-rl-env-message+
               (the fixnum (rl-recv-buffer socket buffer))))
    (rl-read-message buffer)))

