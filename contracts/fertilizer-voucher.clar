;; Fertilizer Voucher Management System
;; Clarity v3 Smart Contract

;; Error Constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-FARMER-EXISTS (err u101))
(define-constant ERR-FARMER-NOT-FOUND (err u102))
(define-constant ERR-INSUFFICIENT-VOUCHERS (err u103))
(define-constant ERR-VOUCHER-EXPIRED (err u104))
(define-constant ERR-INVALID-AMOUNT (err u105))
(define-constant ERR-ALREADY-VERIFIED (err u106))
(define-constant ERR-NOT-VERIFIED (err u107))

;; Contract Owner
(define-constant CONTRACT-OWNER tx-sender)

;; Data Variables
(define-data-var total-vouchers-issued uint u0)
(define-data-var total-vouchers-redeemed uint u0)

;; Data Maps
(define-map farmers
    principal
    {
        verified: bool,
        voucher-balance: uint,
        total-received: uint,
        total-redeemed: uint,
        registration-block: uint
    }
)

(define-map voucher-transactions
    uint
    {
        farmer: principal,
        amount: uint,
        transaction-type: (string-ascii 20),
        stacks-block-height: uint,
        timestamp: uint
    }
)

(define-map authorized-issuers principal bool)

;; Private Functions
(define-private (is-authorized-issuer (issuer principal))
    (default-to false (map-get? authorized-issuers issuer))
)

;; Public Functions - Farmer Management
(define-public (register-farmer (farmer principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (is-none (map-get? farmers farmer)) ERR-FARMER-EXISTS)
        (ok (map-set farmers farmer {
            verified: false,
            voucher-balance: u0,
            total-received: u0,
            total-redeemed: u0,
            registration-block: stacks-block-height
        }))
    )
)

(define-public (verify-farmer (farmer principal))
    (let ((farmer-data (unwrap! (map-get? farmers farmer) ERR-FARMER-NOT-FOUND)))
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (not (get verified farmer-data)) ERR-ALREADY-VERIFIED)
        (ok (map-set farmers farmer (merge farmer-data { verified: true })))
    )
)

;; Public Functions - Voucher Issuance
(define-public (issue-vouchers (farmer principal) (amount uint))
    (let (
        (farmer-data (unwrap! (map-get? farmers farmer) ERR-FARMER-NOT-FOUND))
        (tx-id (var-get total-vouchers-issued))
    )
        (asserts! (or (is-eq tx-sender CONTRACT-OWNER) (is-authorized-issuer tx-sender)) ERR-NOT-AUTHORIZED)
        (asserts! (get verified farmer-data) ERR-NOT-VERIFIED)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        
        (map-set farmers farmer (merge farmer-data {
            voucher-balance: (+ (get voucher-balance farmer-data) amount),
            total-received: (+ (get total-received farmer-data) amount)
        }))
        
        (map-set voucher-transactions tx-id {
            farmer: farmer,
            amount: amount,
            transaction-type: "ISSUE",
            stacks-block-height: stacks-block-height,
            timestamp: stacks-block-height
        })
        
        (var-set total-vouchers-issued (+ tx-id u1))
        (ok amount)
    )
)

;; Public Functions - Voucher Redemption
(define-public (redeem-vouchers (amount uint))
    (let (
        (farmer-data (unwrap! (map-get? farmers tx-sender) ERR-FARMER-NOT-FOUND))
        (tx-id (var-get total-vouchers-redeemed))
    )
        (asserts! (get verified farmer-data) ERR-NOT-VERIFIED)
        (asserts! (>= (get voucher-balance farmer-data) amount) ERR-INSUFFICIENT-VOUCHERS)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        
        (map-set farmers tx-sender (merge farmer-data {
            voucher-balance: (- (get voucher-balance farmer-data) amount),
            total-redeemed: (+ (get total-redeemed farmer-data) amount)
        }))
        
        (map-set voucher-transactions tx-id {
            farmer: tx-sender,
            amount: amount,
            transaction-type: "REDEEM",
            stacks-block-height: stacks-block-height,
            timestamp: stacks-block-height
        })
        
        (var-set total-vouchers-redeemed (+ tx-id u1))
        (ok amount)
    )
)

;; Public Functions - Authorization Management
(define-public (add-authorized-issuer (issuer principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (ok (map-set authorized-issuers issuer true))
    )
)

(define-public (remove-authorized-issuer (issuer principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (ok (map-delete authorized-issuers issuer))
    )
)

;; Read-Only Functions
(define-read-only (get-farmer-info (farmer principal))
    (map-get? farmers farmer)
)

(define-read-only (get-voucher-balance (farmer principal))
    (match (map-get? farmers farmer)
        farmer-data (ok (get voucher-balance farmer-data))
        ERR-FARMER-NOT-FOUND
    )
)

(define-read-only (get-transaction (tx-id uint))
    (map-get? voucher-transactions tx-id)
)

(define-read-only (get-total-vouchers-issued)
    (ok (var-get total-vouchers-issued))
)

(define-read-only (get-total-vouchers-redeemed)
    (ok (var-get total-vouchers-redeemed))
)

(define-read-only (is-farmer-verified (farmer principal))
    (match (map-get? farmers farmer)
        farmer-data (ok (get verified farmer-data))
        ERR-FARMER-NOT-FOUND
    )
)
