;; Data Integration Contract
;; Integrates reporting data from various sources

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_DATA_SOURCE_NOT_FOUND (err u201))
(define-constant ERR_INVALID_DATA (err u202))
(define-constant ERR_INTEGRATION_FAILED (err u203))

;; Data structures
(define-map data-sources
  { source-id: uint }
  {
    name: (string-ascii 50),
    endpoint: (string-ascii 200),
    active: bool,
    last-sync: uint,
    data-hash: (buff 32)
  }
)

(define-map integration-logs
  { log-id: uint }
  {
    source-id: uint,
    timestamp: uint,
    status: (string-ascii 20),
    data-count: uint
  }
)

(define-data-var next-source-id uint u1)
(define-data-var next-log-id uint u1)

;; Data source management
(define-public (register-data-source (name (string-ascii 50)) (endpoint (string-ascii 200)))
  (let ((source-id (var-get next-source-id)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set data-sources
      { source-id: source-id }
      {
        name: name,
        endpoint: endpoint,
        active: true,
        last-sync: u0,
        data-hash: 0x00
      }
    )
    (var-set next-source-id (+ source-id u1))
    (ok source-id)
  )
)

(define-public (sync-data-source (source-id uint) (data-hash (buff 32)) (record-count uint))
  (match (map-get? data-sources { source-id: source-id })
    source-data
    (if (get active source-data)
      (begin
        (map-set data-sources
          { source-id: source-id }
          (merge source-data {
            last-sync: block-height,
            data-hash: data-hash
          })
        )
        (log-integration source-id "SUCCESS" record-count)
        (ok true)
      )
      ERR_DATA_SOURCE_NOT_FOUND
    )
    ERR_DATA_SOURCE_NOT_FOUND
  )
)

(define-private (log-integration (source-id uint) (status (string-ascii 20)) (data-count uint))
  (let ((log-id (var-get next-log-id)))
    (map-set integration-logs
      { log-id: log-id }
      {
        source-id: source-id,
        timestamp: block-height,
        status: status,
        data-count: data-count
      }
    )
    (var-set next-log-id (+ log-id u1))
    log-id
  )
)

;; Fixed function - consistent return types
(define-read-only (is-data-fresh (source-id uint) (max-age uint))
  (match (map-get? data-sources { source-id: source-id })
    source-data
    (ok (<= (- block-height (get last-sync source-data)) max-age))
    (ok false)
  )
)

(define-read-only (get-data-source (source-id uint))
  (map-get? data-sources { source-id: source-id })
)

(define-read-only (get-integration-log (log-id uint))
  (map-get? integration-logs { log-id: log-id })
)
