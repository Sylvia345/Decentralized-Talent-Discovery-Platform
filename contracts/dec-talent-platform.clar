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
(define-constant ERR_MILESTONE_NOT_FOUND (err u410))
(define-constant ERR_MILESTONE_ALREADY_COMPLETED (err u411))
(define-constant ERR_INSUFFICIENT_MILESTONE_VOTES (err u412))
(define-constant ERR_ALL_MILESTONES_COMPLETED (err u413))
(define-constant ERR_DISPUTE_EXISTS (err u414))
(define-constant ERR_DISPUTE_NOT_FOUND (err u415))
(define-constant ERR_DISPUTE_CLOSED (err u416))
(define-constant ERR_ALREADY_VOTED_DISPUTE (err u417))
(define-constant ERR_ALREADY_REFERRED (err u418))
(define-constant ERR_CANNOT_REFER_SELF (err u419))
(define-constant ERR_REFERRAL_NOT_FOUND (err u420))

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

(define-map project-milestones
  { project-id: uint, milestone-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 300),
    funding-percentage: uint,
    completed: bool,
    completion-votes: uint,
    required-votes: uint,
    created-at: uint
  }
)

(define-map milestone-votes
  { project-id: uint, milestone-id: uint, voter: principal }
  { timestamp: uint }
)

(define-map project-disputes
  uint
  {
    project-id: uint,
    initiator: principal,
    reason: (string-ascii 300),
    status: (string-ascii 20),
    votes-for: uint,
    votes-against: uint,
    created-at: uint,
    resolved-at: uint
  }
)

(define-map dispute-votes
  { project-id: uint, voter: principal }
  { vote: bool, timestamp: uint }
)

(define-data-var next-dispute-id uint u1)
(define-data-var referral-reward-points uint u10)

(define-map talent-referrals
  { referred: principal }
  { referrer: principal, referred-at: uint, reward-claimed: bool }
)

(define-map referrer-stats
  principal
  { total-referrals: uint, successful-referrals: uint, total-reward-points: uint }
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

(define-read-only (get-project-milestone (project-id uint) (milestone-id uint))
  (map-get? project-milestones { project-id: project-id, milestone-id: milestone-id })
)

(define-read-only (get-milestone-vote (project-id uint) (milestone-id uint) (voter principal))
  (map-get? milestone-votes { project-id: project-id, milestone-id: milestone-id, voter: voter })
)

(define-read-only (get-dispute (dispute-id uint))
  (map-get? project-disputes dispute-id)
)

(define-read-only (get-dispute-vote (project-id uint) (voter principal))
  (map-get? dispute-votes { project-id: project-id, voter: voter })
)

(define-read-only (get-talent-referral (referred principal))
  (map-get? talent-referrals { referred: referred })
)

(define-read-only (get-referrer-stats (referrer principal))
  (map-get? referrer-stats referrer)
)

(define-read-only (get-referral-reward-points)
  (var-get referral-reward-points)
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

(define-public (create-milestone 
  (project-id uint)
  (milestone-id uint)
  (title (string-ascii 100))
  (description (string-ascii 300))
  (funding-percentage uint)
)
  (let
    (
      (project (unwrap! (get-project project-id) ERR_NOT_FOUND))
      (existing-milestone (get-project-milestone project-id milestone-id))
    )
    (asserts! (is-eq (get artist project) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status project) "active") ERR_PROJECT_CLOSED)
    (asserts! (is-none existing-milestone) ERR_SKILL_EXISTS)
    (asserts! (and (> funding-percentage u0) (<= funding-percentage u100)) ERR_INVALID_AMOUNT)
    
    (let
      (
        (support-count u3)
        (calculated-votes (/ support-count u2))
        (required-votes (if (> calculated-votes u1) calculated-votes u1))
      )
      (map-set project-milestones { project-id: project-id, milestone-id: milestone-id }
        {
          title: title,
          description: description,
          funding-percentage: funding-percentage,
          completed: false,
          completion-votes: u0,
          required-votes: required-votes,
          created-at: stacks-block-height
        }
      )
    )
    (ok true)
  )
)

(define-private (get-supporter-count (unused principal))
  u1
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

(define-public (vote-milestone-completion (project-id uint) (milestone-id uint))
  (let
    (
      (project (unwrap! (get-project project-id) ERR_NOT_FOUND))
      (milestone (unwrap! (get-project-milestone project-id milestone-id) ERR_MILESTONE_NOT_FOUND))
      (support (unwrap! (get-project-support project-id tx-sender) ERR_UNAUTHORIZED))
      (existing-vote (get-milestone-vote project-id milestone-id tx-sender))
    )
    (asserts! (is-none existing-vote) ERR_ALREADY_VOTED)
    (asserts! (not (get completed milestone)) ERR_MILESTONE_ALREADY_COMPLETED)
    (asserts! (is-eq (get status project) "active") ERR_PROJECT_CLOSED)
    
    (map-set milestone-votes { project-id: project-id, milestone-id: milestone-id, voter: tx-sender }
      { timestamp: stacks-block-height }
    )
    
    (let
      (
        (new-votes (+ (get completion-votes milestone) u1))
      )
      (map-set project-milestones { project-id: project-id, milestone-id: milestone-id }
        (merge milestone { completion-votes: new-votes })
      )
      
      (if (>= new-votes (get required-votes milestone))
        (begin
          (map-set project-milestones { project-id: project-id, milestone-id: milestone-id }
            (merge milestone { 
              completion-votes: new-votes,
              completed: true
            })
          )
          (try! (release-milestone-funds project-id milestone-id))
          (ok true)
        )
        (ok true)
      )
    )
  )
)

(define-public (release-milestone-funds (project-id uint) (milestone-id uint))
  (let
    (
      (project (unwrap! (get-project project-id) ERR_NOT_FOUND))
      (milestone (unwrap! (get-project-milestone project-id milestone-id) ERR_MILESTONE_NOT_FOUND))
    )
    (asserts! (get completed milestone) ERR_INSUFFICIENT_MILESTONE_VOTES)
    (asserts! (is-eq (get status project) "active") ERR_PROJECT_CLOSED)
    
    (let
      (
        (release-amount (/ (* (get current-funding project) (get funding-percentage milestone)) u100))
      )
      (try! (as-contract (stx-transfer? release-amount tx-sender (get artist project))))
      
      (map-set projects project-id
        (merge project { current-funding: (- (get current-funding project) release-amount) })
      )
      
      (match (get-artist-profile (get artist project))
        profile (map-set artist-profiles (get artist project)
          (merge profile { reputation-score: (+ (get reputation-score profile) u1) })
        )
        true
      )
      
      (ok release-amount)
    )
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

(define-read-only (get-milestone-status (project-id uint) (milestone-id uint))
  (match (get-project-milestone project-id milestone-id)
    milestone (ok {
      title: (get title milestone),
      description: (get description milestone),
      funding-percentage: (get funding-percentage milestone),
      completed: (get completed milestone),
      completion-votes: (get completion-votes milestone),
      required-votes: (get required-votes milestone),
      vote-percentage: (if (> (get required-votes milestone) u0)
        (/ (* (get completion-votes milestone) u100) (get required-votes milestone))
        u0
      ),
      created-at: (get created-at milestone)
    })
    ERR_MILESTONE_NOT_FOUND
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

(define-public (raise-dispute (project-id uint) (reason (string-ascii 300)))
  (let
    (
      (project (unwrap! (get-project project-id) ERR_NOT_FOUND))
      (support (unwrap! (get-project-support project-id tx-sender) ERR_UNAUTHORIZED))
      (dispute-id (var-get next-dispute-id))
    )
    (asserts! (is-eq (get status project) "active") ERR_PROJECT_CLOSED)
    
    (map-set project-disputes dispute-id
      {
        project-id: project-id,
        initiator: tx-sender,
        reason: reason,
        status: "active",
        votes-for: u1,
        votes-against: u0,
        created-at: stacks-block-height,
        resolved-at: u0
      }
    )
    
    (map-set dispute-votes { project-id: project-id, voter: tx-sender }
      { vote: true, timestamp: stacks-block-height }
    )
    
    (var-set next-dispute-id (+ dispute-id u1))
    (ok dispute-id)
  )
)

(define-public (vote-on-dispute (dispute-id uint) (vote-for bool))
  (let
    (
      (dispute (unwrap! (get-dispute dispute-id) ERR_DISPUTE_NOT_FOUND))
      (project-id (get project-id dispute))
      (support (unwrap! (get-project-support project-id tx-sender) ERR_UNAUTHORIZED))
      (existing-vote (get-dispute-vote project-id tx-sender))
    )
    (asserts! (is-eq (get status dispute) "active") ERR_DISPUTE_CLOSED)
    (asserts! (is-none existing-vote) ERR_ALREADY_VOTED_DISPUTE)
    
    (map-set dispute-votes { project-id: project-id, voter: tx-sender }
      { vote: vote-for, timestamp: stacks-block-height }
    )
    
    (let
      (
        (new-votes-for (if vote-for (+ (get votes-for dispute) u1) (get votes-for dispute)))
        (new-votes-against (if vote-for (get votes-against dispute) (+ (get votes-against dispute) u1)))
        (total-votes (+ new-votes-for new-votes-against))
      )
      (map-set project-disputes dispute-id
        (merge dispute { 
          votes-for: new-votes-for,
          votes-against: new-votes-against
        })
      )
      
      (if (>= total-votes u5)
        (resolve-dispute dispute-id)
        (ok false)
      )
    )
  )
)

(define-public (resolve-dispute (dispute-id uint))
  (let
    (
      (dispute (unwrap! (get-dispute dispute-id) ERR_DISPUTE_NOT_FOUND))
      (project-id (get project-id dispute))
      (project (unwrap! (get-project project-id) ERR_NOT_FOUND))
      (votes-for (get votes-for dispute))
      (votes-against (get votes-against dispute))
      (total-votes (+ votes-for votes-against))
    )
    (asserts! (is-eq (get status dispute) "active") ERR_DISPUTE_CLOSED)
    (asserts! (>= total-votes u5) ERR_INSUFFICIENT_MILESTONE_VOTES)
    
    (let
      (
        (dispute-passed (> votes-for votes-against))
        (refund-percentage (if dispute-passed u50 u0))
      )
      (map-set project-disputes dispute-id
        (merge dispute { 
          status: (if dispute-passed "upheld" "rejected"),
          resolved-at: stacks-block-height
        })
      )
      
      (if dispute-passed
        (begin
          (map-set projects project-id
            (merge project { status: "disputed" })
          )
          (ok true)
        )
        (ok false)
      )
    )
  )
)

(define-read-only (get-dispute-status (dispute-id uint))
  (match (get-dispute dispute-id)
    dispute (ok {
      project-id: (get project-id dispute),
      initiator: (get initiator dispute),
      reason: (get reason dispute),
      status: (get status dispute),
      votes-for: (get votes-for dispute),
      votes-against: (get votes-against dispute),
      total-votes: (+ (get votes-for dispute) (get votes-against dispute)),
      vote-percentage-for: (if (> (+ (get votes-for dispute) (get votes-against dispute)) u0)
        (/ (* (get votes-for dispute) u100) (+ (get votes-for dispute) (get votes-against dispute)))
        u0
      ),
      created-at: (get created-at dispute),
      resolved-at: (get resolved-at dispute)
    })
    ERR_DISPUTE_NOT_FOUND
  )
)

(define-public (refer-talent (referred principal))
  (let
    (
      (existing-referral (get-talent-referral referred))
      (current-stats (get-referrer-stats tx-sender))
    )
    (asserts! (not (is-eq tx-sender referred)) ERR_CANNOT_REFER_SELF)
    (asserts! (is-none existing-referral) ERR_ALREADY_REFERRED)
    
    (map-set talent-referrals { referred: referred }
      { referrer: tx-sender, referred-at: stacks-block-height, reward-claimed: false }
    )
    
    (match current-stats
      stats (map-set referrer-stats tx-sender
        (merge stats { total-referrals: (+ (get total-referrals stats) u1) })
      )
      (map-set referrer-stats tx-sender
        { total-referrals: u1, successful-referrals: u0, total-reward-points: u0 }
      )
    )
    (ok true)
  )
)

(define-public (claim-referral-reward (referred principal))
  (let
    (
      (referral (unwrap! (get-talent-referral referred) ERR_REFERRAL_NOT_FOUND))
      (referred-profile (unwrap! (get-artist-profile referred) ERR_NOT_FOUND))
      (referrer (get referrer referral))
      (referrer-profile (get-artist-profile referrer))
      (reward-points (var-get referral-reward-points))
    )
    (asserts! (is-eq tx-sender referrer) ERR_UNAUTHORIZED)
    (asserts! (not (get reward-claimed referral)) ERR_ALREADY_REFERRED)
    (asserts! (> (get successful-projects referred-profile) u0) ERR_INVALID_STATUS)
    
    (map-set talent-referrals { referred: referred }
      (merge referral { reward-claimed: true })
    )
    
    (match referrer-profile
      profile (begin
        (map-set artist-profiles referrer
          (merge profile { reputation-score: (+ (get reputation-score profile) reward-points) })
        )
        (map-set referrer-stats referrer
          {
            total-referrals: (match (get-referrer-stats referrer)
              stats (get total-referrals stats)
              u1
            ),
            successful-referrals: (+ (match (get-referrer-stats referrer)
              stats (get successful-referrals stats)
              u0
            ) u1),
            total-reward-points: (+ (match (get-referrer-stats referrer)
              stats (get total-reward-points stats)
              u0
            ) reward-points)
          }
        )
        (ok true)
      )
      ERR_NOT_FOUND
    )
  )
)

(define-public (update-referral-reward-points (new-points uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (and (> new-points u0) (<= new-points u100)) ERR_INVALID_AMOUNT)
    (var-set referral-reward-points new-points)
    (ok true)
  )
)

(define-read-only (get-referral-status (referred principal))
  (match (get-talent-referral referred)
    referral (ok {
      referrer: (get referrer referral),
      referred-at: (get referred-at referral),
      reward-claimed: (get reward-claimed referral),
      eligible-for-reward: (match (get-artist-profile referred)
        profile (> (get successful-projects profile) u0)
        false
      )
    })
    ERR_REFERRAL_NOT_FOUND
  )
)
