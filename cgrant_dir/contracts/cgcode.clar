;; Community Grants Platform (Stage 1: Basic Submission)
;; Commit Message: Initialize core project submission and retrieval functionality

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant MINIMUM_GRANT_AMOUNT u100)
(define-constant MAX_GRANT u1000000000)
(define-constant MIN_NAME_LENGTH u4)
(define-constant MIN_PROPOSAL_LENGTH u10)

;; Error codes
(define-constant ERR_INVALID_PROJECT (err u101))
(define-constant ERR_INVALID_AMOUNT (err u107))
(define-constant ERR_INVALID_NAME (err u109))
(define-constant ERR_INVALID_PROPOSAL (err u110))

;; Data Maps and Variables
(define-map Projects
    { project-id: uint }
    {
        coordinator: principal,
        name: (string-ascii 100),
        proposal: (string-ascii 500),
        total-grant: uint,
        status: (string-ascii 20)
    }
)

(define-data-var project-counter uint u0)

;; Private validation functions
(define-private (is-valid-amount (amount uint))
    (and (> amount u0) (<= amount MAX_GRANT))
)

(define-private (is-valid-name (name (string-ascii 100)))
    (>= (len name) MIN_NAME_LENGTH)
)

(define-private (is-valid-proposal (proposal (string-ascii 500)))
    (>= (len proposal) MIN_PROPOSAL_LENGTH)
)

;; Public functions
(define-public (submit-project (name (string-ascii 100)) 
                             (proposal (string-ascii 500)) 
                             (total-grant uint))
    (begin
        (asserts! (is-valid-name name) ERR_INVALID_NAME)
        (asserts! (is-valid-proposal proposal) ERR_INVALID_PROPOSAL)
        (asserts! (is-valid-amount total-grant) ERR_INVALID_AMOUNT)
        
        (let ((project-id (+ (var-get project-counter) u1)))
            (map-set Projects
                { project-id: project-id }
                {
                    coordinator: tx-sender,
                    name: name,
                    proposal: proposal,
                    total-grant: total-grant,
                    status: "ACTIVE"
                }
            )
            (var-set project-counter project-id)
            (ok project-id)
        )
    )
)

;; Read-only functions
(define-read-only (get-project (project-id uint))
    (map-get? Projects {project-id: project-id})
)

(define-read-only (get-project-count)
    (var-get project-counter)
)