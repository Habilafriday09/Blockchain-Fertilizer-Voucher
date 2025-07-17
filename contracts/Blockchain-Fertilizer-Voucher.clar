(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_VOUCHER_NOT_FOUND (err u101))
(define-constant ERR_VOUCHER_ALREADY_REDEEMED (err u102))
(define-constant ERR_VOUCHER_EXPIRED (err u103))
(define-constant ERR_INSUFFICIENT_STOCK (err u104))
(define-constant ERR_INVALID_FARMER (err u105))
(define-constant ERR_INVALID_AMOUNT (err u106))
(define-constant ERR_SEASON_NOT_ACTIVE (err u107))
(define-constant ERR_DEALER_NOT_AUTHORIZED (err u108))
(define-constant ERR_VOUCHER_LIMIT_EXCEEDED (err u109))

(define-data-var contract-admin principal CONTRACT_OWNER)
(define-data-var total-vouchers-issued uint u0)
(define-data-var total-vouchers-redeemed uint u0)
(define-data-var current-season uint u1)
(define-data-var season-active bool true)
(define-data-var max-vouchers-per-farmer uint u5)

(define-map vouchers
    { voucher-id: uint }
    {
        farmer: principal,
        amount: uint,
        fertilizer-type: (string-ascii 50),
        issued-at: uint,
        expires-at: uint,
        redeemed: bool,
        redeemed-at: (optional uint),
        dealer: (optional principal),
        season: uint,
    }
)

(define-map farmers
    { farmer-address: principal }
    {
        name: (string-ascii 100),
        id-number: (string-ascii 50),
        location: (string-ascii 100),
        vouchers-received: uint,
        vouchers-redeemed: uint,
        season: uint,
        verified: bool,
    }
)

(define-map authorized-dealers
    { dealer-address: principal }
    {
        name: (string-ascii 100),
        location: (string-ascii 100),
        license-number: (string-ascii 50),
        active: bool,
    }
)

(define-map fertilizer-inventory
    { fertilizer-type: (string-ascii 50) }
    {
        total-stock: uint,
        reserved-stock: uint,
        price-per-unit: uint,
        subsidy-percentage: uint,
    }
)

(define-map season-stats
    { season: uint }
    {
        vouchers-issued: uint,
        vouchers-redeemed: uint,
        total-subsidy-amount: uint,
        start-block: uint,
        end-block: (optional uint),
    }
)

(define-read-only (get-contract-info)
    {
        admin: (var-get contract-admin),
        total-vouchers-issued: (var-get total-vouchers-issued),
        total-vouchers-redeemed: (var-get total-vouchers-redeemed),
        current-season: (var-get current-season),
        season-active: (var-get season-active),
        max-vouchers-per-farmer: (var-get max-vouchers-per-farmer),
        current-block: stacks-block-height,
    }
)

(define-read-only (get-voucher-details (voucher-id uint))
    (map-get? vouchers { voucher-id: voucher-id })
)

(define-read-only (get-farmer-info (farmer-address principal))
    (map-get? farmers { farmer-address: farmer-address })
)

(define-read-only (get-dealer-info (dealer-address principal))
    (map-get? authorized-dealers { dealer-address: dealer-address })
)

(define-read-only (get-fertilizer-stock (fertilizer-type (string-ascii 50)))
    (map-get? fertilizer-inventory { fertilizer-type: fertilizer-type })
)

(define-read-only (get-season-statistics (season uint))
    (map-get? season-stats { season: season })
)

(define-read-only (is-voucher-valid (voucher-id uint))
    (match (map-get? vouchers { voucher-id: voucher-id })
        voucher-data (and
            (not (get redeemed voucher-data))
            (< stacks-block-height (get expires-at voucher-data))
            (var-get season-active)
        )
        false
    )
)

(define-read-only (calculate-subsidy-amount
        (fertilizer-type (string-ascii 50))
        (amount uint)
    )
    (match (map-get? fertilizer-inventory { fertilizer-type: fertilizer-type })
        inventory-data (let (
                (price-per-unit (get price-per-unit inventory-data))
                (subsidy-rate (get subsidy-percentage inventory-data))
            )
            (/ (* (* amount price-per-unit) subsidy-rate) u100)
        )
        u0
    )
)

(define-private (is-admin (caller principal))
    (is-eq caller (var-get contract-admin))
)

(define-private (is-dealer-authorized (dealer principal))
    (match (map-get? authorized-dealers { dealer-address: dealer })
        dealer-data (get active dealer-data)
        false
    )
)

(define-private (validate-farmer (farmer principal))
    (match (map-get? farmers { farmer-address: farmer })
        farmer-data (get verified farmer-data)
        false
    )
)

(define-private (increment-voucher-counter)
    (var-set total-vouchers-issued (+ (var-get total-vouchers-issued) u1))
)

(define-private (get-next-voucher-id)
    (+ (var-get total-vouchers-issued) u1)
)

(define-public (set-admin (new-admin principal))
    (begin
        (asserts! (is-admin tx-sender) ERR_NOT_AUTHORIZED)
        (var-set contract-admin new-admin)
        (ok true)
    )
)

(define-public (register-farmer
        (farmer principal)
        (name (string-ascii 100))
        (id-number (string-ascii 50))
        (location (string-ascii 100))
    )
    (begin
        (asserts! (is-admin tx-sender) ERR_NOT_AUTHORIZED)
        (map-set farmers { farmer-address: farmer } {
            name: name,
            id-number: id-number,
            location: location,
            vouchers-received: u0,
            vouchers-redeemed: u0,
            season: (var-get current-season),
            verified: true,
        })
        (ok true)
    )
)

(define-public (register-dealer
        (dealer principal)
        (name (string-ascii 100))
        (location (string-ascii 100))
        (license-number (string-ascii 50))
    )
    (begin
        (asserts! (is-admin tx-sender) ERR_NOT_AUTHORIZED)
        (map-set authorized-dealers { dealer-address: dealer } {
            name: name,
            location: location,
            license-number: license-number,
            active: true,
        })
        (ok true)
    )
)

(define-public (add-fertilizer-type
        (fertilizer-type (string-ascii 50))
        (stock uint)
        (price-per-unit uint)
        (subsidy-percentage uint)
    )
    (begin
        (asserts! (is-admin tx-sender) ERR_NOT_AUTHORIZED)
        (asserts!
            (and
                (> stock u0)
                (> price-per-unit u0)
                (<= subsidy-percentage u100)
            )
            ERR_INVALID_AMOUNT
        )
        (map-set fertilizer-inventory { fertilizer-type: fertilizer-type } {
            total-stock: stock,
            reserved-stock: u0,
            price-per-unit: price-per-unit,
            subsidy-percentage: subsidy-percentage,
        })
        (ok true)
    )
)

(define-public (issue-voucher
        (farmer principal)
        (amount uint)
        (fertilizer-type (string-ascii 50))
        (validity-blocks uint)
    )
    (let (
            (voucher-id (get-next-voucher-id))
            (current-block stacks-block-height)
            (expires-at (+ current-block validity-blocks))
        )
        (begin
            (asserts! (is-admin tx-sender) ERR_NOT_AUTHORIZED)
            (asserts! (var-get season-active) ERR_SEASON_NOT_ACTIVE)
            (asserts! (validate-farmer farmer) ERR_INVALID_FARMER)
            (asserts! (> amount u0) ERR_INVALID_AMOUNT)

            (let ((farmer-data (unwrap-panic (map-get? farmers { farmer-address: farmer }))))
                (asserts!
                    (< (get vouchers-received farmer-data)
                        (var-get max-vouchers-per-farmer)
                    )
                    ERR_VOUCHER_LIMIT_EXCEEDED
                )

                (map-set farmers { farmer-address: farmer }
                    (merge farmer-data { vouchers-received: (+ (get vouchers-received farmer-data) u1) })
                )
            )

            (let ((inventory-data (unwrap!
                    (map-get? fertilizer-inventory { fertilizer-type: fertilizer-type })
                    ERR_INSUFFICIENT_STOCK
                )))
                (asserts!
                    (>=
                        (- (get total-stock inventory-data)
                            (get reserved-stock inventory-data)
                        )
                        amount
                    )
                    ERR_INSUFFICIENT_STOCK
                )
                (map-set fertilizer-inventory { fertilizer-type: fertilizer-type }
                    (merge inventory-data { reserved-stock: (+ (get reserved-stock inventory-data) amount) })
                )
            )

            (map-set vouchers { voucher-id: voucher-id } {
                farmer: farmer,
                amount: amount,
                fertilizer-type: fertilizer-type,
                issued-at: current-block,
                expires-at: expires-at,
                redeemed: false,
                redeemed-at: none,
                dealer: none,
                season: (var-get current-season),
            })

            (increment-voucher-counter)
            (ok voucher-id)
        )
    )
)

(define-public (redeem-voucher (voucher-id uint))
    (let ((voucher-data (unwrap! (map-get? vouchers { voucher-id: voucher-id })
            ERR_VOUCHER_NOT_FOUND
        )))
        (begin
            (asserts! (is-dealer-authorized tx-sender) ERR_DEALER_NOT_AUTHORIZED)
            (asserts! (not (get redeemed voucher-data))
                ERR_VOUCHER_ALREADY_REDEEMED
            )
            (asserts! (< stacks-block-height (get expires-at voucher-data))
                ERR_VOUCHER_EXPIRED
            )
            (asserts! (var-get season-active) ERR_SEASON_NOT_ACTIVE)

            (let (
                    (fertilizer-type (get fertilizer-type voucher-data))
                    (amount (get amount voucher-data))
                    (farmer (get farmer voucher-data))
                )
                (let ((inventory-data (unwrap!
                        (map-get? fertilizer-inventory { fertilizer-type: fertilizer-type })
                        ERR_INSUFFICIENT_STOCK
                    )))
                    (map-set fertilizer-inventory { fertilizer-type: fertilizer-type }
                        (merge inventory-data {
                            reserved-stock: (- (get reserved-stock inventory-data) amount),
                            total-stock: (- (get total-stock inventory-data) amount),
                        })
                    )
                )

                (let ((farmer-data (unwrap! (map-get? farmers { farmer-address: farmer })
                        ERR_INVALID_FARMER
                    )))
                    (map-set farmers { farmer-address: farmer }
                        (merge farmer-data { vouchers-redeemed: (+ (get vouchers-redeemed farmer-data) u1) })
                    )
                )

                (map-set vouchers { voucher-id: voucher-id }
                    (merge voucher-data {
                        redeemed: true,
                        redeemed-at: (some stacks-block-height),
                        dealer: (some tx-sender),
                    })
                )

                (var-set total-vouchers-redeemed
                    (+ (var-get total-vouchers-redeemed) u1)
                )
                (ok true)
            )
        )
    )
)

(define-public (start-new-season)
    (begin
        (asserts! (is-admin tx-sender) ERR_NOT_AUTHORIZED)

        (match (map-get? season-stats { season: (var-get current-season) })
            current-season-data (map-set season-stats { season: (var-get current-season) }
                (merge current-season-data { end-block: (some stacks-block-height) })
            )
            (map-set season-stats { season: (var-get current-season) } {
                vouchers-issued: (var-get total-vouchers-issued),
                vouchers-redeemed: (var-get total-vouchers-redeemed),
                total-subsidy-amount: u0,
                start-block: stacks-block-height,
                end-block: (some stacks-block-height),
            })
        )

        (var-set current-season (+ (var-get current-season) u1))
        (var-set season-active true)
        (var-set total-vouchers-issued u0)
        (var-set total-vouchers-redeemed u0)

        (map-set season-stats { season: (var-get current-season) } {
            vouchers-issued: u0,
            vouchers-redeemed: u0,
            total-subsidy-amount: u0,
            start-block: stacks-block-height,
            end-block: none,
        })

        (ok (var-get current-season))
    )
)

(define-public (toggle-season-status)
    (begin
        (asserts! (is-admin tx-sender) ERR_NOT_AUTHORIZED)
        (var-set season-active (not (var-get season-active)))
        (ok (var-get season-active))
    )
)

(define-public (update-voucher-limit (new-limit uint))
    (begin
        (asserts! (is-admin tx-sender) ERR_NOT_AUTHORIZED)
        (asserts! (> new-limit u0) ERR_INVALID_AMOUNT)
        (var-set max-vouchers-per-farmer new-limit)
        (ok true)
    )
)

(define-public (deactivate-dealer (dealer principal))
    (begin
        (asserts! (is-admin tx-sender) ERR_NOT_AUTHORIZED)
        (match (map-get? authorized-dealers { dealer-address: dealer })
            dealer-data (begin
                (map-set authorized-dealers { dealer-address: dealer }
                    (merge dealer-data { active: false })
                )
                (ok true)
            )
            ERR_DEALER_NOT_AUTHORIZED
        )
    )
)

(define-public (bulk-register-farmers (farmers-list (list
    50
    {
        farmer: principal,
        name: (string-ascii 100),
        id-number: (string-ascii 50),
        location: (string-ascii 100),
    }
)))
    (begin
        (asserts! (is-admin tx-sender) ERR_NOT_AUTHORIZED)
        (fold register-farmer-helper farmers-list (ok true))
    )
)

(define-private (register-farmer-helper
        (farmer-info {
            farmer: principal,
            name: (string-ascii 100),
            id-number: (string-ascii 50),
            location: (string-ascii 100),
        })
        (prev-result (response bool uint))
    )
    (match prev-result
        success (begin
            (map-set farmers { farmer-address: (get farmer farmer-info) } {
                name: (get name farmer-info),
                id-number: (get id-number farmer-info),
                location: (get location farmer-info),
                vouchers-received: u0,
                vouchers-redeemed: u0,
                season: (var-get current-season),
                verified: true,
            })
            (ok true)
        )
        error
        prev-result
    )
)

(define-public (get-farmer-voucher-count (farmer principal))
    (match (map-get? farmers { farmer-address: farmer })
        farmer-data (ok {
            vouchers-received: (get vouchers-received farmer-data),
            vouchers-redeemed: (get vouchers-redeemed farmer-data),
            remaining-limit: (- (var-get max-vouchers-per-farmer)
                (get vouchers-received farmer-data)
            ),
        })
        ERR_INVALID_FARMER
    )
)

(define-public (update-fertilizer-stock
        (fertilizer-type (string-ascii 50))
        (new-stock uint)
    )
    (begin
        (asserts! (is-admin tx-sender) ERR_NOT_AUTHORIZED)
        (asserts! (> new-stock u0) ERR_INVALID_AMOUNT)
        (match (map-get? fertilizer-inventory { fertilizer-type: fertilizer-type })
            inventory-data (begin
                (map-set fertilizer-inventory { fertilizer-type: fertilizer-type }
                    (merge inventory-data { total-stock: new-stock })
                )
                (ok true)
            )
            ERR_INSUFFICIENT_STOCK
        )
    )
)

(define-public (emergency-cancel-voucher (voucher-id uint))
    (begin
        (asserts! (is-admin tx-sender) ERR_NOT_AUTHORIZED)
        (let ((voucher-data (unwrap! (map-get? vouchers { voucher-id: voucher-id })
                ERR_VOUCHER_NOT_FOUND
            )))
            (asserts! (not (get redeemed voucher-data))
                ERR_VOUCHER_ALREADY_REDEEMED
            )

            (let (
                    (fertilizer-type (get fertilizer-type voucher-data))
                    (amount (get amount voucher-data))
                )
                (let ((inventory-data (unwrap!
                        (map-get? fertilizer-inventory { fertilizer-type: fertilizer-type })
                        ERR_INSUFFICIENT_STOCK
                    )))
                    (map-set fertilizer-inventory { fertilizer-type: fertilizer-type }
                        (merge inventory-data { reserved-stock: (- (get reserved-stock inventory-data) amount) })
                    )
                )
            )

            (map-delete vouchers { voucher-id: voucher-id })
            (ok true)
        )
    )
)

(define-read-only (get-available-stock (fertilizer-type (string-ascii 50)))
    (match (map-get? fertilizer-inventory { fertilizer-type: fertilizer-type })
        inventory-data (ok (- (get total-stock inventory-data) (get reserved-stock inventory-data)))
        ERR_INSUFFICIENT_STOCK
    )
)

(define-read-only (get-contract-statistics)
    (ok {
        total-vouchers-issued: (var-get total-vouchers-issued),
        total-vouchers-redeemed: (var-get total-vouchers-redeemed),
        redemption-rate: (if (> (var-get total-vouchers-issued) u0)
            (/ (* (var-get total-vouchers-redeemed) u100)
                (var-get total-vouchers-issued)
            )
            u0
        ),
        current-season: (var-get current-season),
        season-active: (var-get season-active),
        current-block: stacks-block-height,
    })
)
