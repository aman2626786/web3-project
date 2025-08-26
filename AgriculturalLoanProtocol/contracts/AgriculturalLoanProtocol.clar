;; AgriculturalLoan Protocol
;; Decentralized farming loans with crop-based collateral and seasonal payment flexibility.

;; --- Constants and Errors ---
(define-constant contract-owner tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-LOAN-NOT-FOUND (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-LOAN-NOT-PENDING (err u103))
(define-constant ERR-ALREADY-PROCESSED (err u104))
(define-constant ERR-INVALID-STRING (err u105))

;; --- Data Storage ---

;; A counter to assign a unique ID to each loan request
(define-data-var loan-id-counter uint u0)

;; Map to store loan details
;; key: loan-id (uint)
;; value: a tuple containing loan details
(define-map loans uint {
    farmer: principal,
    crop-type: (string-ascii 50),
    loan-amount: uint,
    repayment-season: (string-ascii 20),
    land-deed-hash: (buff 64),
    status: (string-ascii 10) ;; "pending", "approved", "repaid", "defaulted"
})

;; --- Public Functions ---

;; Function for a farmer to request a new loan
;; @param crop-type: The type of crop being cultivated (e.g., "Wheat", "Corn")
;; @param loan-amount: The amount of STX the farmer is requesting
;; @param repayment-season: The season when the loan is expected to be repaid (e.g., "Winter 2025")
(define-public (request-loan (crop-type (string-ascii 50)) (loan-amount uint) (repayment-season (string-ascii 20)) (land-deed-hash (buff 64)))
  (begin
    ;; Ensure the loan amount is greater than zero
    (asserts! (> loan-amount u0) ERR-INVALID-AMOUNT)
    ;; Ensure string inputs are not empty
    (asserts! (> (len crop-type) u0) ERR-INVALID-STRING)
    (asserts! (> (len repayment-season) u0) ERR-INVALID-STRING)
    (asserts! (not (is-eq land-deed-hash 0x)) ERR-INVALID-STRING)

    ;; Get the next available loan ID and increment the counter
    (let ((next-loan-id (+ (var-get loan-id-counter) u1)))
      (var-set loan-id-counter next-loan-id)

      ;; Store the new loan request
      (map-set loans next-loan-id {
        farmer: tx-sender,
        crop-type: crop-type,
        loan-amount: loan-amount,
        repayment-season: repayment-season,
        land-deed-hash: land-deed-hash,
        status: "pending"
      })

      ;; Print an event for off-chain monitoring
      (print {
        type: "loan-request",
        loan-id: next-loan-id,
        farmer: tx-sender
      })

      ;; Return the new loan ID
      (ok next-loan-id)
    )
  )
)

;; Function for the contract owner to approve a pending loan request
;; @param loan-id: The ID of the loan to be approved
(define-public (approve-loan (id uint))
  (begin
    ;; Only the contract owner can call this function
    (asserts! (is-eq tx-sender contract-owner) ERR-OWNER-ONLY)

    ;; Fetch the loan details from the map
    (let ((loan-details (unwrap! (map-get? loans id) ERR-LOAN-NOT-FOUND)))

      ;; Ensure the loan is still in "pending" status
      (asserts! (is-eq (get status loan-details) "pending") ERR-LOAN-NOT-PENDING)

      ;; Transfer the loan amount from the contract to the farmer
      ;; Note: This assumes the contract has sufficient funds, which would be managed
      ;; by a separate treasury/funding mechanism.
      (try! (stx-transfer? (get loan-amount loan-details) (as-contract tx-sender) (get farmer loan-details)))

      ;; Update the loan status to "approved"
      (map-set loans id (merge loan-details {status: "approved"}))

      ;; Print an event for off-chain monitoring
      (print {
        type: "loan-approval",
        loan-id: id,
        farmer: (get farmer loan-details)
      })

      (ok true)
    )
  )
)
