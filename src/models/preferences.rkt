#lang racket

(provide (struct-out course-preference)
         (struct-out preferences))

(struct course-preference (course-code allowed-groups) #:transparent)
(struct preferences (min-credits max-credits courses) #:transparent)
