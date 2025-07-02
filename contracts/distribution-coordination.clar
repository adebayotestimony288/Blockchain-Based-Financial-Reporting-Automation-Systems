;; Distribution Coordination Contract
;; Coordinates report distribution

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_RECIPIENT_NOT_FOUND (err u501))
(define-constant ERR_DISTRIBUTION_FAILED (err u502))
(define-constant ERR_INVALID_CHANNEL (err u503))

;; Data structures
(define-map distribution-channels
  { channel-id: uint }
  {
    name: (string-ascii 50),
    channel-type: (string-ascii 20),
    endpoint: (string-ascii 200),
    active: bool,
    created-at: uint
  }
)

(define-map recipients
  { recipient-id: uint }
  {
    address: principal,
    email: (string-ascii 100),
    channels: (list 10 uint),
    active: bool
  }
)

(define-map distribution-logs
  { distribution-id: uint }
  {
    report-id: uint,
    recipient-id: uint,
    channel-id: uint,
    status: (string-ascii 20),
    distributed-at: uint
  }
)

(define-data-var next-channel-id uint u1)
(define-data-var next-recipient-id uint u1)
(define-data-var next-distribution-id uint u1)

;; Channel management
(define-public (create-distribution-channel
  (name (string-ascii 50))
  (channel-type (string-ascii 20))
  (endpoint (string-ascii 200)))
  (let ((channel-id (var-get next-channel-id)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set distribution-channels
      { channel-id: channel-id }
      {
        name: name,
        channel-type: channel-type,
        endpoint: endpoint,
        active: true,
        created-at: block-height
      }
    )
    (var-set next-channel-id (+ channel-id u1))
    (ok channel-id)
  )
)

(define-public (register-recipient
  (address principal)
  (email (string-ascii 100))
  (channels (list 10 uint)))
  (let ((recipient-id (var-get next-recipient-id)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set recipients
      { recipient-id: recipient-id }
      {
        address: address,
        email: email,
        channels: channels,
        active: true
      }
    )
    (var-set next-recipient-id (+ recipient-id u1))
    (ok recipient-id)
  )
)

(define-public (distribute-report (report-id uint) (recipient-id uint) (channel-id uint))
  (match (map-get? recipients { recipient-id: recipient-id })
    recipient-data
    (match (map-get? distribution-channels { channel-id: channel-id })
      channel-data
      (if (and (get active recipient-data) (get active channel-data))
        (let ((distribution-id (var-get next-distribution-id)))
          (map-set distribution-logs
            { distribution-id: distribution-id }
            {
              report-id: report-id,
              recipient-id: recipient-id,
              channel-id: channel-id,
              status: "SENT",
              distributed-at: block-height
            }
          )
          (var-set next-distribution-id (+ distribution-id u1))
          (ok distribution-id)
        )
        ERR_DISTRIBUTION_FAILED
      )
      ERR_INVALID_CHANNEL
    )
    ERR_RECIPIENT_NOT_FOUND
  )
)

;; Fixed function - consistent return types
(define-read-only (is-channel-active (channel-id uint))
  (match (map-get? distribution-channels { channel-id: channel-id })
    channel-data
    (ok (get active channel-data))
    (ok false)
  )
)

(define-read-only (get-distribution-channel (channel-id uint))
  (map-get? distribution-channels { channel-id: channel-id })
)

(define-read-only (get-recipient (recipient-id uint))
  (map-get? recipients { recipient-id: recipient-id })
)

(define-read-only (get-distribution-log (distribution-id uint))
  (map-get? distribution-logs { distribution-id: distribution-id })
)

(define-public (update-distribution-status (distribution-id uint) (status (string-ascii 20)))
  (match (map-get? distribution-logs { distribution-id: distribution-id })
    log-data
    (begin
      (map-set distribution-logs
        { distribution-id: distribution-id }
        (merge log-data { status: status })
      )
      (ok true)
    )
    ERR_DISTRIBUTION_FAILED
  )
)
