;; RepLedger - Decentralized Reputation Ledger for Web3 Communities

;; Error codes
(define-constant ERR-NOT-ADMIN (err u100))
(define-constant ERR-ADMIN-NOT-FOUND (err u101))
(define-constant ERR-NOT-AUTHORIZED (err u102))
(define-constant ERR-INVALID-POINTS (err u103))
(define-constant ERR-INSUFFICIENT-REPUTATION (err u104))
(define-constant ERR-USER-NOT-FOUND (err u105))

;; Data maps
(define-map user-reputation 
  { user: principal } 
  { score: int, last-updated: uint })

(define-map admins 
  { addr: principal } 
  { is-admin: bool })

;; Contract deployer becomes default admin
(map-set admins { addr: tx-sender } { is-admin: true })

;; ============ HELPER FUNCTIONS ============

(define-private (is-admin-check (who principal))
  (default-to false (get is-admin (map-get? admins { addr: who }))))

;; ============ ADMIN FUNCTIONS ============

(define-public (add-admin (new-admin principal))
  (begin
    (asserts! (is-admin-check tx-sender) ERR-NOT-ADMIN)
    (asserts! (not (is-eq new-admin tx-sender)) (err u106)) ;; Prevent self-addition
    (map-set admins { addr: new-admin } { is-admin: true })
    (ok true)))

(define-public (remove-admin (admin principal))
  (begin
    (asserts! (is-admin-check tx-sender) ERR-NOT-ADMIN)
    (asserts! (not (is-eq admin tx-sender)) (err u107)) ;; Prevent self-removal
    (asserts! (is-some (map-get? admins { addr: admin })) ERR-ADMIN-NOT-FOUND)
    (map-delete admins { addr: admin })
    (ok true)))

;; ============ REPUTATION ACTIONS ============

(define-public (award-reputation (user principal) (points int))
  (begin
    (asserts! (is-admin-check tx-sender) ERR-NOT-ADMIN)
    (asserts! (> points 0) ERR-INVALID-POINTS)
    (let ((current (default-to { score: 0, last-updated: u0 } 
                               (map-get? user-reputation { user: user }))))
      (let ((new-score (+ (get score current) points)))
        (map-set user-reputation { user: user }
          { score: new-score, last-updated: stacks-block-height })
        (print { action: "award", user: user, points: points, new-score: new-score })
        (ok new-score)))))

(define-public (revoke-reputation (user principal) (points int))
  (begin
    (asserts! (is-admin-check tx-sender) ERR-NOT-ADMIN)
    (asserts! (> points 0) ERR-INVALID-POINTS)
    (let ((current (default-to { score: 0, last-updated: u0 } 
                               (map-get? user-reputation { user: user }))))
      (let ((new-score (- (get score current) points)))
        (map-set user-reputation { user: user }
          { score: new-score, last-updated: stacks-block-height })
        (print { action: "revoke", user: user, points: points, new-score: new-score })
        (ok new-score)))))

(define-public (reset-reputation (user principal))
  (begin
    (asserts! (is-admin-check tx-sender) ERR-NOT-ADMIN)
    (map-set user-reputation { user: user }
      { score: 0, last-updated: stacks-block-height })
    (print { action: "reset", user: user })
    (ok true)))

;; ============ READ-ONLY FUNCTIONS ============

(define-read-only (get-reputation (user principal))
  (ok (get score (default-to { score: 0, last-updated: u0 } 
                             (map-get? user-reputation { user: user })))))

(define-read-only (get-user-details (user principal))
  (ok (default-to { score: 0, last-updated: u0 } 
                  (map-get? user-reputation { user: user }))))

(define-read-only (is-admin (who principal))
  (ok (is-admin-check who)))

(define-read-only (get-contract-info)
  (ok {
    name: "RepLedger",
    version: "1.0.0",
    description: "Decentralized Reputation Ledger for Web3 Communities"
  }))

;; ============ BATCH OPERATIONS ============

(define-public (batch-award-reputation (users (list 10 principal)) (points int))
  (begin
    (asserts! (is-admin-check tx-sender) ERR-NOT-ADMIN)
    (asserts! (> points 0) ERR-INVALID-POINTS)
    (ok (map award-single-user users))))

(define-private (award-single-user (user principal))
  (let ((current (default-to { score: 0, last-updated: u0 } 
                             (map-get? user-reputation { user: user }))))
    (map-set user-reputation { user: user }
      { score: (+ (get score current) 1), last-updated: stacks-block-height })
    user))
