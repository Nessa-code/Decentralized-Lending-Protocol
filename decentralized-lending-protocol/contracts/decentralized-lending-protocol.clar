;; Decentralized Lending Protocol
;; Allows users to deposit collateral and borrow against it

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u301))
(define-constant ERR_LOAN_NOT_FOUND (err u302))
(define-constant ERR_INSUFFICIENT_BALANCE (err u303))
(define-constant ERR_LIQUIDATION_NOT_ALLOWED (err u304))
(define-constant ERR_INVALID_AMOUNT (err u305))

;; Protocol parameters
(define-data-var collateral-ratio uint u150) ;; 150% minimum collateralization
(define-data-var liquidation-threshold uint u120) ;; 120% liquidation threshold
(define-data-var interest-rate uint u500) ;; 5% annual interest rate
(define-data-var liquidation-bonus uint u1050) ;; 5% liquidation bonus

;; Protocol state
(define-data-var total-collateral uint u0)
(define-data-var total-borrowed uint u0)
(define-data-var next-loan-id uint u1)

;; User data
(define-map user-collateral principal uint)
(define-map user-borrowed principal uint)
(define-map user-last-update principal uint)

;; Loan data
(define-map loans
  uint
  {
    borrower: principal,
    collateral-amount: uint,
    borrowed-amount: uint,
    last-update: uint
  }
)

;; Helper functions
(define-private (min-uint (a uint) (b uint))
  (if (< a b) a b)
)

;; Read-only functions
(define-read-only (get-user-collateral (user principal))
  (default-to u0 (map-get? user-collateral user))
)

(define-read-only (get-user-borrowed (user principal))
  (default-to u0 (map-get? user-borrowed user))
)

(define-read-only (get-loan (loan-id uint))
  (map-get? loans loan-id)
)

(define-read-only (calculate-interest (principal-amount uint) (blocks-elapsed uint))
  (/ (* principal-amount (var-get interest-rate) blocks-elapsed) u52560000) ;; Assuming ~52560 blocks per year
)

(define-read-only (get-health-factor (user principal))
  (let (
    (collateral (get-user-collateral user))
    (borrowed (get-user-borrowed user))
  )
    (if (is-eq borrowed u0)
      u999999 ;; Very high health factor if no debt
      (/ (* collateral u100) borrowed)
    )
  )
)

(define-read-only (can-liquidate (user principal))
  (< (get-health-factor user) (var-get liquidation-threshold))
)

(define-read-only (get-max-borrow (user principal))
  (let (
    (collateral (get-user-collateral user))
  )
    (/ (* collateral u100) (var-get collateral-ratio))
  )
)

;; Public functions
(define-public (deposit-collateral (amount uint))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (let (
      (current-collateral (get-user-collateral tx-sender))
      (new-collateral (+ current-collateral amount))
    )
      (map-set user-collateral tx-sender new-collateral)
      (var-set total-collateral (+ (var-get total-collateral) amount))
      (ok new-collateral)
    )
  )
)

(define-public (withdraw-collateral (amount uint))
  (let (
    (current-collateral (get-user-collateral tx-sender))
    (current-borrowed (get-user-borrowed tx-sender))
    (remaining-collateral (- current-collateral amount))
  )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= current-collateral amount) ERR_INSUFFICIENT_COLLATERAL)
    
    ;; Check if withdrawal maintains collateral ratio
    (if (> current-borrowed u0)
      (asserts! (>= (/ (* remaining-collateral u100) current-borrowed) (var-get collateral-ratio)) ERR_INSUFFICIENT_COLLATERAL)
      true
    )
    
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    (map-set user-collateral tx-sender remaining-collateral)
    (var-set total-collateral (- (var-get total-collateral) amount))
    (ok remaining-collateral)
  )
)

(define-public (borrow (amount uint))
  (let (
    (current-collateral (get-user-collateral tx-sender))
    (current-borrowed (get-user-borrowed tx-sender))
    (max-borrow (get-max-borrow tx-sender))
    (new-borrowed (+ current-borrowed amount))
  )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= new-borrowed max-borrow) ERR_INSUFFICIENT_COLLATERAL)
    
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    
    (map-set user-borrowed tx-sender new-borrowed)
    (map-set user-last-update tx-sender stacks-block-height)
    (var-set total-borrowed (+ (var-get total-borrowed) amount))
    
    (ok new-borrowed)
  )
)

(define-public (repay (amount uint))
  (let (
    (current-borrowed (get-user-borrowed tx-sender))
    (repay-amount (min-uint amount current-borrowed))
    (new-borrowed (- current-borrowed repay-amount))
  )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> current-borrowed u0) ERR_INSUFFICIENT_BALANCE)
    
    (try! (stx-transfer? repay-amount tx-sender (as-contract tx-sender)))
    
    (map-set user-borrowed tx-sender new-borrowed)
    (var-set total-borrowed (- (var-get total-borrowed) repay-amount))
    
    (ok new-borrowed)
  )
)

(define-public (liquidate (user principal) (repay-amount uint))
  (let (
    (borrowed-amount (get-user-borrowed user))
    (collateral-amount (get-user-collateral user))
    (collateral-to-seize (/ (* repay-amount (var-get liquidation-bonus)) u100))
  )
    (asserts! (can-liquidate user) ERR_LIQUIDATION_NOT_ALLOWED)
    (asserts! (> repay-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= repay-amount borrowed-amount) ERR_INVALID_AMOUNT)
    (asserts! (<= collateral-to-seize collateral-amount) ERR_INSUFFICIENT_COLLATERAL)
    
    ;; Repay debt
    (try! (stx-transfer? repay-amount tx-sender (as-contract tx-sender)))
    
    ;; Transfer collateral to liquidator
    (try! (as-contract (stx-transfer? collateral-to-seize tx-sender tx-sender)))
    
    ;; Update user balances
    (map-set user-borrowed user (- borrowed-amount repay-amount))
    (map-set user-collateral user (- collateral-amount collateral-to-seize))
    
    ;; Update protocol totals
    (var-set total-borrowed (- (var-get total-borrowed) repay-amount))
    (var-set total-collateral (- (var-get total-collateral) collateral-to-seize))
    
    (ok collateral-to-seize)
  )
)

;; Admin functions
(define-public (set-collateral-ratio (new-ratio uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set collateral-ratio new-ratio)
    (ok true)
  )
)

(define-public (set-interest-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set interest-rate new-rate)
    (ok true)
  )
)
