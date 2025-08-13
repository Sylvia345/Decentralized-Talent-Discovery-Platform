;; title: dec-talent-platform

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_INVALID_AMOUNT (err u400))
(define-constant ERR_INSUFFICIENT_FUNDS (err u402))
(define-constant ERR_ALREADY_VOTED (err u403))
(define-constant ERR_PROJECT_CLOSED (err u405))
(define-constant ERR_INVALID_STATUS (err u406))
(define-constant ERR_SKILL_EXISTS (err u407))
(define-constant ERR_CANNOT_ENDORSE_SELF (err u408))
(define-constant ERR_ALREADY_ENDORSED (err u409))

(define-data-var next-project-id uint u1)
(define-data-var platform-fee uint u500)

(define-map projects
  uint
  {
    artist: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    funding-goal: uint,
    current-funding: uint,
    votes: uint,
    status: (string-ascii 20),
    created-at: uint,
    deadline: uint,
    collaboration-open: bool
  }
)

(define-map project-supporters
  { project-id: uint, supporter: principal }
  { amount: uint, voted: bool, timestamp: uint }
)

(define-map artist-profiles
  principal
  {
    name: (string-ascii 50),
    bio: (string-ascii 300),
    portfolio-url: (string-ascii 100),
    reputation-score: uint,
    total-projects: uint,
    successful-projects: uint
  }
)

(define-map collaboration-requests
  { project-id: uint, requester: principal }
  { message: (string-ascii 200), status: (string-ascii 20), timestamp: uint }
)

(define-map artist-skills
  { artist: principal, skill: (string-ascii 30) }
  { endorsement-count: uint, verified: bool, registered-at: uint }
)

(define-map skill-endorsements
  { artist: principal, skill: (string-ascii 30), endorser: principal }
  { timestamp: uint, reputation-weight: uint }
)

(define-read-only (get-project (project-id uint))
  (map-get? projects project-id)
)

(define-read-only (get-project-support (project-id uint) (supporter principal))
  (map-get? project-supporters { project-id: project-id, supporter: supporter })
)

(define-read-only (get-artist-profile (artist principal))
  (map-get? artist-profiles artist)
)

(define-read-only (get-collaboration-request (project-id uint) (requester principal))
  (map-get? collaboration-requests { project-id: project-id, requester: requester })
)

(define-read-only (get-artist-skill (artist principal) (skill (string-ascii 30)))
  (map-get? artist-skills { artist: artist, skill: skill })
)

(define-read-only (get-skill-endorsement (artist principal) (skill (string-ascii 30)) (endorser principal))
  (map-get? skill-endorsements { artist: artist, skill: skill, endorser: endorser })
)

(define-read-only (get-next-project-id)
  (var-get next-project-id)
)

(define-read-only (get-platform-fee)
  (var-get platform-fee)
)

(define-public (create-artist-profile (name (string-ascii 50)) (bio (string-ascii 300)) (portfolio-url (string-ascii 100)))
  (begin
    (map-set artist-profiles tx-sender
      {
        name: name,
        bio: bio,
        portfolio-url: portfolio-url,
        reputation-score: u0,
        total-projects: u0,
        successful-projects: u0
      }
    )
    (ok true)
  )
)

(define-public (create-project 
  (title (string-ascii 100))
  (description (string-ascii 500))
  (funding-goal uint)
  (duration-blocks uint)
  (collaboration-open bool)
)
  (let
    (
      (project-id (var-get next-project-id))
      (deadline (+ stacks-block-height duration-blocks))
    )
    (asserts! (> funding-goal u0) ERR_INVALID_AMOUNT)
    (map-set projects project-id
      {
        artist: tx-sender,
        title: title,
        description: description,
        funding-goal: funding-goal,
        current-funding: u0,
        votes: u0,
        status: "active",
        created-at: stacks-block-height,
        deadline: deadline,
        collaboration-open: collaboration-open
      }
    )
    (var-set next-project-id (+ project-id u1))
    (match (get-artist-profile tx-sender)
      profile (map-set artist-profiles tx-sender
        (merge profile { total-projects: (+ (get total-projects profile) u1) })
      )
      (begin
        (unwrap! (create-artist-profile "Anonymous" "Artist on the platform" "") (err u500))
        true
      )
    )
    (ok project-id)
  )
)

(define-public (support-project (project-id uint) (amount uint))
  (let
    (
      (project (unwrap! (get-project project-id) ERR_NOT_FOUND))
      (existing-support (get-project-support project-id tx-sender))
      (fee (/ (* amount (var-get platform-fee)) u10000))
      (support-amount (- amount fee))
    )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (is-eq (get status project) "active") ERR_PROJECT_CLOSED)
    (asserts! (<= stacks-block-height (get deadline project)) ERR_PROJECT_CLOSED)
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (match existing-support
      support (map-set project-supporters { project-id: project-id, supporter: tx-sender }
        (merge support { 
          amount: (+ (get amount support) support-amount),
          timestamp: stacks-block-height
        })
      )
      (map-set project-supporters { project-id: project-id, supporter: tx-sender }
        {
          amount: support-amount,
          voted: false,
          timestamp: stacks-block-height
        }
      )
    )
    
    (map-set projects project-id
      (merge project { current-funding: (+ (get current-funding project) support-amount) })
    )
    
    (ok true)
  )
)

(define-public (vote-for-project (project-id uint))
  (let
    (
      (project (unwrap! (get-project project-id) ERR_NOT_FOUND))
      (support (unwrap! (get-project-support project-id tx-sender) ERR_UNAUTHORIZED))
    )
    (asserts! (not (get voted support)) ERR_ALREADY_VOTED)
    (asserts! (is-eq (get status project) "active") ERR_PROJECT_CLOSED)
    
    (map-set project-supporters { project-id: project-id, supporter: tx-sender }
      (merge support { voted: true })
    )
    
    (map-set projects project-id
      (merge project { votes: (+ (get votes project) u1) })
    )
    
    (ok true)
  )
)

(define-public (withdraw-funding (project-id uint))
  (let
    (
      (project (unwrap! (get-project project-id) ERR_NOT_FOUND))
      (withdrawal-amount (get current-funding project))
    )
    (asserts! (is-eq (get artist project) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (or 
      (>= (get current-funding project) (get funding-goal project))
      (> stacks-block-height (get deadline project))
    ) ERR_PROJECT_CLOSED)
    
    (try! (as-contract (stx-transfer? withdrawal-amount tx-sender (get artist project))))
    
    (map-set projects project-id
      (merge project { 
        status: "completed",
        current-funding: u0
      })
    )
    
    (match (get-artist-profile (get artist project))
      profile (map-set artist-profiles (get artist project)
        (merge profile { 
          reputation-score: (+ (get reputation-score profile) (get votes project)),
          successful-projects: (+ (get successful-projects profile) u1)
        })
      )
      true
    )
    
    (ok withdrawal-amount)
  )
)

(define-public (request-collaboration (project-id uint) (message (string-ascii 200)))
  (let
    (
      (project (unwrap! (get-project project-id) ERR_NOT_FOUND))
    )
    (asserts! (get collaboration-open project) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status project) "active") ERR_PROJECT_CLOSED)
    (asserts! (not (is-eq (get artist project) tx-sender)) ERR_UNAUTHORIZED)
    
    (map-set collaboration-requests { project-id: project-id, requester: tx-sender }
      {
        message: message,
        status: "pending",
        timestamp: stacks-block-height
      }
    )
    
    (ok true)
  )
)

(define-public (respond-to-collaboration (project-id uint) (requester principal) (accept bool))
  (let
    (
      (project (unwrap! (get-project project-id) ERR_NOT_FOUND))
      (request (unwrap! (get-collaboration-request project-id requester) ERR_NOT_FOUND))
    )
    (asserts! (is-eq (get artist project) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status request) "pending") ERR_INVALID_STATUS)
    
    (map-set collaboration-requests { project-id: project-id, requester: requester }
      (merge request { status: (if accept "accepted" "rejected") })
    )
    
    (ok true)
  )
)

(define-public (close-project (project-id uint))
  (let
    (
      (project (unwrap! (get-project project-id) ERR_NOT_FOUND))
    )
    (asserts! (is-eq (get artist project) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status project) "active") ERR_INVALID_STATUS)
    
    (map-set projects project-id
      (merge project { status: "closed" })
    )
    
    (ok true)
  )
)

(define-public (register-skill (skill (string-ascii 30)))
  (let
    (
      (existing-skill (get-artist-skill tx-sender skill))
    )
    (asserts! (is-none existing-skill) ERR_SKILL_EXISTS)
    (map-set artist-skills { artist: tx-sender, skill: skill }
      {
        endorsement-count: u0,
        verified: false,
        registered-at: stacks-block-height
      }
    )
    (ok true)
  )
)

(define-public (endorse-skill (artist principal) (skill (string-ascii 30)))
  (let
    (
      (artist-skill (unwrap! (get-artist-skill artist skill) ERR_NOT_FOUND))
      (existing-endorsement (get-skill-endorsement artist skill tx-sender))
      (endorser-profile (get-artist-profile tx-sender))
      (reputation-weight (match endorser-profile
        profile (+ u1 (/ (get reputation-score profile) u10))
        u1
      ))
    )
    (asserts! (not (is-eq artist tx-sender)) ERR_CANNOT_ENDORSE_SELF)
    (asserts! (is-none existing-endorsement) ERR_ALREADY_ENDORSED)
    
    (map-set skill-endorsements { artist: artist, skill: skill, endorser: tx-sender }
      {
        timestamp: stacks-block-height,
        reputation-weight: reputation-weight
      }
    )
    
    (map-set artist-skills { artist: artist, skill: skill }
      (merge artist-skill { 
        endorsement-count: (+ (get endorsement-count artist-skill) u1),
        verified: (>= (+ (get endorsement-count artist-skill) u1) u3)
      })
    )
    
    (ok true)
  )
)

(define-public (update-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= new-fee u1000) ERR_INVALID_AMOUNT)
    (var-set platform-fee new-fee)
    (ok true)
  )
)

(define-read-only (get-project-stats (project-id uint))
  (match (get-project project-id)
    project (ok {
      funding-percentage: (if (> (get funding-goal project) u0)
        (/ (* (get current-funding project) u100) (get funding-goal project))
        u0
      ),
      time-remaining: (if (> (get deadline project) stacks-block-height)
        (- (get deadline project) stacks-block-height)
        u0
      ),
      is-funded: (>= (get current-funding project) (get funding-goal project))
    })
    ERR_NOT_FOUND
  )
)

(define-read-only (get-artist-stats (artist principal))
  (match (get-artist-profile artist)
    profile (ok {
      success-rate: (if (> (get total-projects profile) u0)
        (/ (* (get successful-projects profile) u100) (get total-projects profile))
        u0
      ),
      avg-reputation: (if (> (get total-projects profile) u0)
        (/ (get reputation-score profile) (get total-projects profile))
        u0
      )
    })
    ERR_NOT_FOUND
  )
)

(define-read-only (get-skill-verification-status (artist principal) (skill (string-ascii 30)))
  (match (get-artist-skill artist skill)
    skill-data (ok {
      endorsement-count: (get endorsement-count skill-data),
      verified: (get verified skill-data),
      registered-at: (get registered-at skill-data),
      verification-percentage: (if (>= (get endorsement-count skill-data) u3)
        u100
        (/ (* (get endorsement-count skill-data) u100) u3)
      )
    })
    ERR_NOT_FOUND
  )
)
