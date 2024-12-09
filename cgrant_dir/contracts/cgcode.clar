;; Community Grants Platform (CommunityGrants)
;; A system for funding and supporting local community projects with milestone-based grants

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant MINIMUM_GRANT_AMOUNT u100)
(define-constant COMMUNITY_APPROVAL_THRESHOLD u500) ;; 50.0% represented as 500/1000
(define-constant MAX_GRANT u1000000000) ;; Maximum grant amount allowed for projects
(define-constant MIN_NAME_LENGTH u4)
(define-constant MIN_PROPOSAL_LENGTH u10)
(define-constant MAX_REVIEWS u100) ;; Maximum number of community reviews allowed

;; Error codes
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_PROJECT (err u101))
(define-constant ERR_ALREADY_REVIEWED (err u102))
(define-constant ERR_INSUFFICIENT_GRANT (err u103))
(define-constant ERR_REVIEW_CLOSED (err u104))
(define-constant ERR_PHASE_INVALID (err u105))
(define-constant ERR_PROJECT_NOT_APPROVED (err u106))
(define-constant ERR_INVALID_AMOUNT (err u107))
(define-constant ERR_INVALID_PHASE_COUNT (err u108))
(define-constant ERR_INVALID_NAME (err u109))
(define-constant ERR_INVALID_PROPOSAL (err u110))
(define-constant ERR_MAX_REVIEWS_REACHED (err u111))

;; Data Maps and Variables
(define-map Projects
    { project-id: uint }
    {
        coordinator: principal,
        name: (string-ascii 100),
        proposal: (string-ascii 500),
        total-grant: uint,
        phase-count: uint,
        current-phase: uint,
        review-count: uint,
        status: (string-ascii 20),
        total-positive-review: uint,
        total-negative-review: uint,
        total-review-weight: uint
    }
)

(define-map Phases
    { project-id: uint, phase-id: uint }
    {
        funding: uint,
        objectives: (string-ascii 200),
        status: (string-ascii 20),
        completion-report: (optional (string-ascii 200))
    }
)

(define-map Reviews
    { project-id: uint, reviewer: principal }
    {
        amount: uint,
        endorse: bool,
        contribution-amount: uint
    }
)

(define-map ReviewerStakes
    { user: principal }
    { total-contributed: uint }
)

(define-data-var project-counter uint u0)

;; Private functions
(define-private (is-contract-owner)
    (is-eq tx-sender CONTRACT_OWNER)
)

(define-private (calculate-review-weight (contribution-amount uint))
    contribution-amount
)

(define-private (is-valid-project-id (project-id uint))
    (<= project-id (var-get project-counter))
)

(define-private (is-valid-phase-id (phase-id uint) (phase-count uint))
    (< phase-id phase-count)
)

(define-private (is-valid-amount (amount uint))
    (and (> amount u0) (<= amount MAX_GRANT))
)

(define-private (is-valid-name (name (string-ascii 100)))
    (>= (len name) MIN_NAME_LENGTH)
)

(define-private (is-valid-proposal (proposal (string-ascii 500)))
    (>= (len proposal) MIN_PROPOSAL_LENGTH)
)

(define-private (validate-and-process-review (endorse-vote bool) (review-weight uint) (review-data (tuple (total-positive-review uint) (total-negative-review uint) (total-review-weight uint))))
    (let (
        (safe-endorse (validate-endorse-bool endorse-vote))
        (current-positive-review (get total-positive-review review-data))
        (current-negative-review (get total-negative-review review-data))
        (current-total-weight (get total-review-weight review-data))
    )
        {
            total-positive-review: (if safe-endorse 
                (+ current-positive-review review-weight)
                current-positive-review
            ),
            total-negative-review: (if safe-endorse
                current-negative-review
                (+ current-negative-review review-weight)
            ),
            total-review-weight: (+ current-total-weight review-weight)
        }
    )
)

(define-private (validate-endorse-bool (endorse-vote bool))
    (if endorse-vote true false)
)

(define-private (safe-merge-project-reviews (project-map {
        coordinator: principal,
        name: (string-ascii 100),
        proposal: (string-ascii 500),
        total-grant: uint,
        phase-count: uint,
        current-phase: uint,
        review-count: uint,
        status: (string-ascii 20),
        total-positive-review: uint,
        total-negative-review: uint,
        total-review-weight: uint
    }) 
    (review-updates {
        total-positive-review: uint,
        total-negative-review: uint,
        total-review-weight: uint
    }))
    (merge project-map
        {
            total-positive-review: (get total-positive-review review-updates),
            total-negative-review: (get total-negative-review review-updates),
            total-review-weight: (get total-review-weight review-updates)
        }
    )
)

;; Public functions
(define-public (submit-project (name (string-ascii 100)) 
                             (proposal (string-ascii 500)) 
                             (total-grant uint)
                             (phase-count uint))
    (begin
        (asserts! (is-valid-name name) ERR_INVALID_NAME)
        (asserts! (is-valid-proposal proposal) ERR_INVALID_PROPOSAL)
        (asserts! (is-valid-amount total-grant) ERR_INVALID_AMOUNT)
        (asserts! (and (> phase-count u0) (<= phase-count u10)) ERR_INVALID_PHASE_COUNT)
        
        (let ((project-id (+ (var-get project-counter) u1)))
            (map-set Projects
                { project-id: project-id }
                {
                    coordinator: tx-sender,
                    name: name,
                    proposal: proposal,
                    total-grant: total-grant,
                    phase-count: phase-count,
                    current-phase: u0,
                    review-count: u0,
                    status: "ACTIVE",
                    total-positive-review: u0,
                    total-negative-review: u0,
                    total-review-weight: u0
                }
            )
            (var-set project-counter project-id)
            (ok project-id)
        )
    )
)

(define-public (review-project (project-id uint) (endorse bool) (contribution-amount uint))
    (let (
        (project (unwrap! (map-get? Projects {project-id: project-id}) ERR_INVALID_PROJECT))
        (review-weight (calculate-review-weight contribution-amount))
        (safe-endorse (validate-endorse-bool endorse))
    )
        (asserts! (is-valid-project-id project-id) ERR_INVALID_PROJECT)
        (asserts! (>= contribution-amount MINIMUM_GRANT_AMOUNT) ERR_INSUFFICIENT_GRANT)
        (asserts! (< (get review-count project) MAX_REVIEWS) ERR_REVIEW_CLOSED)
        (asserts! (is-eq (get status project) "ACTIVE") ERR_REVIEW_CLOSED)
        (asserts! (is-none (map-get? Reviews {project-id: project-id, reviewer: tx-sender})) ERR_ALREADY_REVIEWED)
        
        (try! (stx-transfer? contribution-amount tx-sender (as-contract tx-sender)))
        
        (map-set Reviews
            {project-id: project-id, reviewer: tx-sender}
            {
                amount: contribution-amount,
                endorse: safe-endorse,
                contribution-amount: contribution-amount
            }
        )
        
        (let (
            (updated-reviews (validate-and-process-review 
                safe-endorse
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
                (merge (safe-merge-project-reviews project updated-reviews)
                    { review-count: (+ (get review-count project) u1) }
                )
            )
            (ok true)
        )
    )
)

(define-public (submit-phase-progress 
    (project-id uint)
    (phase-id uint)
    (report (string-ascii 200)))
    
    (let (
        (project (unwrap! (map-get? Projects {project-id: project-id}) ERR_INVALID_PROJECT))
        (phase (unwrap! (map-get? Phases {project-id: project-id, phase-id: phase-id}) ERR_PHASE_INVALID))
    )
        (asserts! (is-valid-project-id project-id) ERR_INVALID_PROJECT)
        (asserts! (is-valid-phase-id phase-id (get phase-count project)) ERR_PHASE_INVALID)
        (asserts! (is-eq (get coordinator project) tx-sender) ERR_NOT_AUTHORIZED)
        (asserts! (is-eq phase-id (get current-phase project)) ERR_PHASE_INVALID)
        
        (map-set Phases
            {project-id: project-id, phase-id: phase-id}
            (merge phase
                {
                    status: "PENDING_REVIEW",
                    completion-report: (some report)
                }
            )
        )
        (ok true)
    )
)

(define-public (approve-phase (project-id uint) (phase-id uint))
    (let (
        (project (unwrap! (map-get? Projects {project-id: project-id}) ERR_INVALID_PROJECT))
        (phase (unwrap! (map-get? Phases {project-id: project-id, phase-id: phase-id}) ERR_PHASE_INVALID))
    )
        (asserts! (is-valid-project-id project-id) ERR_INVALID_PROJECT)
        (asserts! (is-valid-phase-id phase-id (get phase-count project)) ERR_PHASE_INVALID)
        (asserts! (is-contract-owner) ERR_NOT_AUTHORIZED)
        
        (try! (as-contract (stx-transfer? (get funding phase) tx-sender (get coordinator project))))
        
        (map-set Phases
            {project-id: project-id, phase-id: phase-id}
            (merge phase {status: "COMPLETED"})
        )
        
        (map-set Projects
            {project-id: project-id}
            (merge project
                {
                    current-phase: (+ phase-id u1),
                    status: (if (>= (+ phase-id u1) (get phase-count project))
                        "COMPLETED"
                        "ACTIVE"
                    )
                }
            )
        )
        (ok true)
    )
)

(define-read-only (get-project-result (project-id uint))
    (let ((project (unwrap! (map-get? Projects {project-id: project-id}) ERR_INVALID_PROJECT)))
        (asserts! (is-valid-project-id project-id) ERR_INVALID_PROJECT)
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

;; Read-only functions
(define-read-only (get-project (project-id uint))
    (map-get? Projects {project-id: project-id})
)

(define-read-only (get-phase (project-id uint) (phase-id uint))
    (map-get? Phases {project-id: project-id, phase-id: phase-id})
)

(define-read-only (get-review (project-id uint) (reviewer principal))
    (map-get? Reviews {project-id: project-id, reviewer: reviewer})
)