;; decrypt-arbitrage
;; 
;; A decentralized arbitrage tracking and execution smart contract
;; designed to help users identify and capitalize on cross-exchange
;; price discrepancies on the Stacks blockchain.
;; 
;; The contract enables users to:
;; - Define arbitrage opportunities
;; - Track potential profit margins
;; - Execute and validate cross-exchange trades
;; - Maintain a transparent record of arbitrage activities

;; -----------------
;; Error Constants
;; -----------------
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-TRADE-NOT-FOUND (err u201))
(define-constant ERR-INVALID-TRADE-STATUS (err u202))
(define-constant ERR-TRADE-ALREADY-EXECUTED (err u203))
(define-constant ERR-INSUFFICIENT-MARGIN (err u204))
(define-constant ERR-INVALID-PARAMETERS (err u205))
(define-constant ERR-TRADE-EXPIRED (err u206))

;; -----------------
;; Data Definitions
;; -----------------

;; Trade status enumeration
(define-constant TRADE-STATUS-PENDING u1)
(define-constant TRADE-STATUS-EXECUTED u2)
(define-constant TRADE-STATUS-CANCELLED u3)

;; Profit margin categories
(define-constant MARGIN-LOW u1)
(define-constant MARGIN-MEDIUM u2)
(define-constant MARGIN-HIGH u3)

;; Counter for trade IDs
(define-data-var next-trade-id uint u1)

;; Trade data structure
(define-map trades
  { trade-id: uint }
  {
    trader: principal,
    source-exchange: (string-ascii 50),
    target-exchange: (string-ascii 50),
    token-pair: (string-ascii 20),
    buy-price: uint,
    sell-price: uint,
    trade-volume: uint,
    profit-margin: uint,
    status: uint,
    creation-time: uint,
    execution-time: (optional uint)
  }
)

;; User trade history
(define-map user-trades
  { user: principal }
  { trade-ids: (list 100 uint) }
)

;; -----------------
;; Private Functions
;; -----------------

;; Checks if the caller is the trade owner
(define-private (is-trade-owner (trade-id uint))
  (let (
    (trade-data (unwrap! (map-get? trades { trade-id: trade-id }) false))
  )
    (is-eq tx-sender (get trader trade-data))
  )
)

;; Generates the next trade ID and increments the counter
(define-private (generate-trade-id)
  (let ((current-id (var-get next-trade-id)))
    (var-set next-trade-id (+ current-id u1))
    current-id
  )
)

;; -----------------
;; Read-Only Functions
;; -----------------

;; Get trade details by ID
(define-read-only (get-trade (trade-id uint))
  (map-get? trades { trade-id: trade-id })
)

;; Get user trade history
(define-read-only (get-user-trades (user principal))
  (map-get? user-trades { user: user })
)

;; Calculate potential profit margin
(define-read-only (calculate-profit-margin (buy-price uint) (sell-price uint) (trade-volume uint))
  (let (
    (profit (/ (* (- sell-price buy-price) trade-volume) buy-price))
  )
    (cond 
      ((< profit u5) MARGIN-LOW)
      ((and (>= profit u5) (< profit u15)) MARGIN-MEDIUM)
      (true MARGIN-HIGH)
    )
  )
)

;; -----------------
;; Public Functions
;; -----------------

;; Create a new arbitrage trade opportunity
(define-public (create-trade 
  (source-exchange (string-ascii 50))
  (target-exchange (string-ascii 50))
  (token-pair (string-ascii 20))
  (buy-price uint)
  (sell-price uint)
  (trade-volume uint)
)
  (let (
    (trade-id (generate-trade-id))
    (profit-margin (calculate-profit-margin buy-price sell-price trade-volume))
  )
    ;; Basic validation
    (asserts! (> sell-price buy-price) ERR-INVALID-PARAMETERS)
    (asserts! (> trade-volume u0) ERR-INVALID-PARAMETERS)

    ;; Store trade details
    (map-set trades
      { trade-id: trade-id }
      {
        trader: tx-sender,
        source-exchange: source-exchange,
        target-exchange: target-exchange,
        token-pair: token-pair,
        buy-price: buy-price,
        sell-price: sell-price,
        trade-volume: trade-volume,
        profit-margin: profit-margin,
        status: TRADE-STATUS-PENDING,
        creation-time: block-height,
        execution-time: none
      }
    )

    ;; Update user trade history
    (match (map-get? user-trades { user: tx-sender })
      existing-trades 
        (map-set user-trades 
          { user: tx-sender }
          { trade-ids: (unwrap! (as-max-len? (append (get trade-ids existing-trades) trade-id) u100) ERR-INVALID-PARAMETERS) }
        )
      ;; First trade for the user
      (map-set user-trades 
        { user: tx-sender }
        { trade-ids: (list trade-id) }
      )
    )

    (ok trade-id)
  )
)

;; Update trade status
(define-public (update-trade-status (trade-id uint) (status uint))
  (let (
    (trade-data (unwrap! (map-get? trades { trade-id: trade-id }) ERR-TRADE-NOT-FOUND))
  )
    ;; Check authorization
    (asserts! (is-trade-owner trade-id) ERR-NOT-AUTHORIZED)
    
    ;; Validate status transition
    (asserts! 
      (or 
        (is-eq status TRADE-STATUS-EXECUTED)
        (is-eq status TRADE-STATUS-CANCELLED)
      ) 
      ERR-INVALID-TRADE-STATUS
    )
    
    ;; Update trade status
    (map-set trades
      { trade-id: trade-id }
      (merge trade-data { 
        status: status, 
        execution-time: (if (is-eq status TRADE-STATUS-EXECUTED) 
                             (some block-height) 
                             none) 
      })
    )
    
    (ok true)
  )
)