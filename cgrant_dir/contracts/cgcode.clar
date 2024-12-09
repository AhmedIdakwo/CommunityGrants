;; Community Grants Platform (Stage 3: Full Lifecycle Management)

;; constants
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_GRANT (err u103))
(define-constant ERR_REVIEW_CLOSED (err u104))
(define-constant ERR_ALREADY_REVIEWED (err u102))
(define-constant ERR_PHASE_INVALID (err u105))
(define-constant ERR_INVALID_PHASE_COUNT (err u108))

;; Existing Project and Review maps remain the same, with additions:
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

;; New map to track project phases
(define-map Phases
    { project-id: uint, phase-id: uint }
    {
        funding: uint,
        objectives: (string-ascii 200),
        status: (string-ascii 20),
        completion-report: (optional (string-ascii 200))
    }
)


;; Modified project submission
(define-public (submit-project (name (string-ascii 100)) 
                             (proposal (string-ascii 500)) 
                             (total-grant uint)
                             (phase-count uint))
    (begin
        ;; Previous validations remain the same
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

;; New function to create project phases
(define-public (create-project-phases 
    (project-id uint) 
    (phase-fundings (list 10 uint)) 
    (phase-objectives (list 10 (string-ascii 200))))
    (let (
        (project (unwrap! (map-get? Projects {project-id: project-id}) ERR_INVALID_PROJECT))
    )
        (asserts! (is-eq (get coordinator project) tx-sender) ERR_NOT_AUTHORIZED)
        (asserts! (is-eq (len phase-fundings) (get phase-count project)) ERR_INVALID_PHASE_COUNT)
        (asserts! (is-eq (len phase-objectives) (get phase-count project)) ERR_INVALID_PHASE_COUNT)
        
        (map-set-phases project-id phase-fundings phase-objectives)
        (ok true)
    )
)

;; Private helper function to set phases
(define-private (map-set-phases (project-id uint) (phase-fundings (list 10 uint)) (phase-objectives (list 10 (string-ascii 200))))
    (fold set-individual-phase 
        (zip phase-fundings phase-objectives)
        { project-id: project-id, current-phase: u0 }
    )
)

(define-private (set-individual-phase 
    (phase-data (tuple (funding uint) (objective (string-ascii 200))))
    (context { project-id: uint, current-phase: uint }))
    (let (
        (phase-id (get current-phase context))
    )
        (map-set Phases
            {project-id: (get project-id context), phase-id: phase-id}
            {
                funding: (get funding phase-data),
                objectives: (get objective phase-data),
                status: "PENDING",
                completion-report: none
            }
        )
        {
            project-id: (get project-id context),
            current-phase: (+ phase-id u1)
        }
    )
)

;; Function to submit phase progress report
(define-public (submit-phase-progress 
    (project-id uint)
    (phase-id uint)
    (report (string-ascii 200)))
    
    (let (
        (project (unwrap! (map-get? Projects {project-id: project-id}) ERR_INVALID_PROJECT))
        (phase (unwrap! (map-get? Phases {project-id: project-id, phase-id: phase-id}) ERR_PHASE_INVALID))
    )
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

;; Function to approve project phases
(define-public (approve-phase (project-id uint) (phase-id uint))
    (let (
        (project (unwrap! (map-get? Projects {project-id: project-id}) ERR_INVALID_PROJECT))
        (phase (unwrap! (map-get? Phases {project-id: project-id, phase-id: phase-id}) ERR_PHASE_INVALID))
    )
        (asserts! (is-contract-owner) ERR_NOT_AUTHORIZED)
        
        (try! (as-contract (stx-transfer? (get funding phase) tx-sender (get coordinator project))))
        
        (map-set Phases
            {project-id: project-id, phase-id: phase-id}
            (merge phase {status