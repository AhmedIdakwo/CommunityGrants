;; Community Grants Platform (Stage 2: Community Review)
;; Commit Message: Add community review mechanism with stake-based endorsement

(define-constant CONTRACT_OWNER tx-sender)
(define-constant MINIMUM_GRANT_AMOUNT u100)
(define-constant MAX_GRANT u1000000000)
(define-constant MIN_NAME_LENGTH u4)
(define-constant MIN_PROPOSAL_LENGTH u10)
(define-constant COMMUNITY_APPROVAL_THRESHOLD u500) ;; 50.0% represented as 500/1000
(define-constant MAX_REVIEWS u100)

;; Additional error codes
(define-constant ERR_INSUFFICIENT_GRANT (err u103))
(define-constant ERR_REVIEW_CLOSED (err u104))
(define-constant ERR_ALREADY_REVIEWED (err u102))

(define-map Projects
    { project-id: uint }
    {
        coordinator: principal,
        name: (string-ascii 100),
        proposal: (string-ascii 500),
        total-grant: uint,
        status: (string-ascii 20),
        review-count: uint,
        total-positive-review: uint,
        total-negative-review: uint,
        total-review-weight: uint
    }
)

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


;; Private review calculation functions
(define-private (calculate-review-weight (contribution-amount uint))
    contribution-amount
)

(define-private (validate-and-process-review (endorse-vote bool) (review-weight uint) (review-data (tuple (total-positive-review uint) (total-negative-review uint) (total-review-weight uint))))
    (let (
        (current-positive-review (get total-positive-review review-data))
        (current-negative-review (get total-negative-review review-data))
        (current-total-weight (get total-review-weight review-data))
    )
        {
            total-positive-review: (if endorse-vote 
                (+ current-positive-review review-weight)
                current-positive-review
            ),
            total-negative-review: (if endorse-vote
                current-negative-review
                (+ current-negative-review review-weight)
            ),
            total-review-weight: (+ current-total-weight review-weight)
        }
    )
)

;; New public function for project review
(define-public (review-project (project-id uint) (endorse bool) (contribution-amount uint))
    (let (
        (project (unwrap! (map-get? Projects {project-id: project-id}) ERR_INVALID_PROJECT))
        (review-weight (calculate-review-weight contribution-amount))
    )
        (asserts! (>= contribution-amount MINIMUM_GRANT_AMOUNT) ERR_INSUFFICIENT_GRANT)
        (asserts! (< (get review-count project) MAX_REVIEWS) ERR_REVIEW_CLOSED)
        (asserts! (is-none (map-get? Reviews {project-id: project-id, reviewer: tx-sender})) ERR_ALREADY_REVIEWED)
        
        (try! (stx-transfer? contribution-amount tx-sender (as-contract tx-sender)))
        
        (map-set Reviews
            {project-id: project-id, reviewer: tx-sender}
            {
                amount: contribution-amount,
                endorse: endorse,
                contribution-amount: contribution-amount
            }
        )
        
        (let (
            (updated-reviews (validate-and-process-review 
                endorse
                review-weight
                {
                    total-positive-review: (get total-positive-review project),
                    total-negative-review: (get total-negative-review project),
                    total-review-weight: (get total-review-weight project)
                }
            ))
        )
            (map-set Projects
                {project-id: project-id}
                (merge project 
                    {
                        review-count: (+ (get review-count project) u1),
                        total-positive-review: (get total-positive-review updated-reviews),
                        total-negative-review: (get total-negative-review updated-reviews),
                        total-review-weight: (get total-review-weight updated-reviews)
                    }
                )
            )
            (ok true)
        )
    )
)

;; read-only function to get project review status
(define-read-only (get-project-result (project-id uint))
    (let ((project (unwrap! (map-get? Projects {project-id: project-id}) ERR_INVALID_PROJECT)))
        (let (
            (total-reviews (get total-review-weight project))
            (positive-reviews (get total-positive-review project))
            (review-count (get review-count project))
        )
            (if (>= review-count MAX_REVIEWS)
                (if (and
                    (> total-reviews u0)
                    (>= (* positive-reviews u1000) (* total-reviews COMMUNITY_APPROVAL_THRESHOLD))
                )
                    (ok "APPROVED")
                    (ok "REJECTED")
                )
                (ok "REVIEW_ACTIVE")
            )
        )
    )
)

(define-read-only (get-project (project-id uint))
    (map-get? Projects {project-id: project-id})
)

(define-read-only (get-project-count)
    (var-get project-counter)
)