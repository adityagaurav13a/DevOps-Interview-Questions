# System Design Complete Deep Dive
## Fundamentals + Patterns + Real Designs for DevOps/Cloud Engineers
### Patterns First → Real Designs → Interview Questions

---

## README — How to Use This Document

**Total sections:** 10
**Your strongest designs:** Serverless platform (judicialsolutions.in), CI/CD pipeline
**Target level:** Mid-level to Senior DevOps/Cloud Engineer interviews

### How to answer system design questions:
```
1. CLARIFY    → Ask questions before designing (2-3 minutes)
2. ESTIMATE   → Scale, storage, traffic numbers
3. HIGH LEVEL → Draw boxes and arrows first
4. DEEP DIVE  → Go deep on critical components
5. BOTTLENECKS→ Identify and address weak points
6. TRADEOFFS  → Explain why you chose each component
```

### Power phrases:
- *"Before I design, let me clarify requirements and scale..."*
- *"This is a read-heavy system, so I'd optimise for reads with caching"*
- *"The bottleneck here is the database — I'd add a read replica"*
- *"I'd use async processing here to decouple and scale independently"*
- *"CAP theorem means I must choose between consistency and availability"*

---

## PART 1 — SYSTEM DESIGN FUNDAMENTALS

### Scalability

```
Vertical Scaling (scale up):
  Add more CPU/RAM to existing machine
  Limits: hardware ceiling, single point of failure
  Use for: databases, stateful services (easier to scale up than out)

Horizontal Scaling (scale out):
  Add more machines
  Requires: stateless services (any server can handle any request)
  Load balancer distributes traffic
  Use for: web servers, API servers, microservices

Stateless vs Stateful:
  Stateless: server doesn't store client session data
    Any server can handle any request
    Easy to horizontal scale
    Session data in Redis/DB instead of server memory

  Stateful: server stores client-specific data
    Requests must go to same server (sticky sessions)
    Hard to scale, single point of failure
```

### Availability

```
Availability = uptime / (uptime + downtime)

SLA targets:
  99%    = 87.6 hours downtime/year   (not production grade)
  99.9%  = 8.76 hours downtime/year   (basic production)
  99.99% = 52.6 minutes downtime/year (high availability)
  99.999%= 5.26 minutes downtime/year (five nines — very expensive)

Ways to achieve HA:
  Redundancy: multiple instances of everything
  No single point of failure: if one component fails, system keeps running
  Health checks: detect failures, remove unhealthy instances
  Auto-recovery: automatically replace failed components
  Geographic distribution: survive datacenter/region failures
```

### CAP Theorem

```
In a distributed system, you can only guarantee 2 of 3:

C = Consistency    → every read gets the most recent write
A = Availability   → every request gets a response (not error)
P = Partition Tolerance → system works despite network partitions

Network partitions ALWAYS happen in distributed systems
Therefore: choose CA or CP (P is not optional)

CP (Consistency + Partition Tolerance):
  Returns error if can't guarantee consistent data
  Examples: HBase, Zookeeper, etcd (Kubernetes uses this)
  Use when: financial data, inventory — can't show stale data

AP (Availability + Partition Tolerance):
  Returns best available data even if stale
  Examples: DynamoDB, Cassandra, CouchDB
  Use when: social media feeds, product catalog — stale is okay

Real world: most systems are "eventually consistent"
  Data becomes consistent after a brief delay
  DynamoDB: reads might be 1 second behind writes (eventually consistent)
            unless you pay 2x for strongly consistent reads
```

### Key Numbers to Know

```
Latency:
  L1 cache: 1 ns
  L2 cache: 10 ns
  RAM access: 100 ns
  SSD read: 100 μs
  Network round trip (same datacenter): 500 μs
  HDD read: 1-10 ms
  Network round trip (different regions): 100-150 ms

Storage:
  1 KB = 1,024 bytes
  1 MB = 1,024 KB
  1 GB = 1,024 MB
  1 TB = 1,024 GB
  1 PB = 1,024 TB

Traffic estimation:
  Twitter: 500M tweets/day = ~6,000 tweets/second
  Instagram: 1B photos/day = ~12,000 photos/second
  Average API: 1000 req/sec = 86M requests/day
  
QPS calculation:
  1M users, 10 requests/day each
  = 10M requests/day
  = 10M / 86400 seconds
  ≈ 115 requests/second (average)
  Peak = 3-5x average = 350-575 req/sec
```

### Load Balancing

```
Layer 4 (Transport) Load Balancer:
  Routes based on IP and TCP port
  Fast, simple, no application awareness
  Examples: AWS NLB, HAProxy (L4 mode)
  Use for: high-throughput, non-HTTP (game servers, databases)

Layer 7 (Application) Load Balancer:
  Routes based on HTTP content (path, host, headers, cookies)
  Can do: SSL termination, path routing, sticky sessions
  Examples: AWS ALB, Nginx, Traefik
  Use for: HTTP APIs, microservices, A/B testing

Algorithms:
  Round Robin: requests go to each server in turn
  Least Connections: route to server with fewest active connections
  IP Hash: same client IP always goes to same server (sticky)
  Weighted: more traffic to powerful servers

Health checks:
  LB pings each server periodically
  Failed server removed from rotation
  Recovered server added back
```

---

## PART 2 — CLASSIC DESIGNS: URL SHORTENER + RATE LIMITER

### Design a URL Shortener (bit.ly)

```
Clarify requirements:
  - 100M new URLs per day
  - 10B reads per day (100:1 read:write ratio)
  - URLs expire after 5 years
  - Custom short URLs supported?
  - Analytics needed?

Scale estimation:
  Writes: 100M/day = 1,160/second
  Reads:  10B/day  = 115,700/second (read-heavy!)
  Storage: 100M * 5 years * 365 days * 500 bytes = ~91TB

Architecture:
  
  Client
    ↓
  Load Balancer (ALB)
    ↓
  API Servers (stateless, horizontally scaled)
    ├── POST /shorten → create short URL
    └── GET /{shortCode} → redirect to original
    ↓
  Cache (Redis)  ← check here first (90% hit rate)
    ↓ (cache miss)
  Database (DynamoDB or MySQL)

Short code generation:
  Option 1: Base62 encoding of auto-increment ID
    ID = 12345678
    Base62 = "dnh75" (6 characters = 62^6 = 56B combinations)
  
  Option 2: MD5 hash of URL, take first 7 chars
    Risk: collisions (two URLs → same hash)
    Fix: check if code exists, try next 7 chars
  
  Option 3: UUID (distributed, no coordination needed)
    Too long — shorten with base62

Database schema:
  Table: urls
  - short_code: VARCHAR(7) PRIMARY KEY
  - original_url: VARCHAR(2048)
  - created_at: TIMESTAMP
  - expires_at: TIMESTAMP
  - user_id: VARCHAR(36)
  - click_count: INT

Redirect flow:
  GET /abc123
  1. Check Redis cache for abc123
  2. If hit: return 301/302 redirect to original URL
  3. If miss: query DB, store in Redis (TTL 24h), return redirect
  
  301 vs 302:
    301 Permanent: browser caches, less server load, no analytics
    302 Temporary: browser always hits server, enables analytics
    Use 302 if analytics matter

Bottlenecks and solutions:
  Read bottleneck → Redis cache (read 10B/day, cache hit rate ~90%)
  Write bottleneck → separate write path, async analytics
  Hot URLs → cache them aggressively
  Single DB → read replicas for geographic distribution
```

### Design a Rate Limiter

```
Clarify:
  - Per user, per IP, or per API key?
  - Hard limit (reject) or soft limit (queue)?
  - 100 req/min per user

Algorithms:

1. Token Bucket (most common):
   - Bucket holds N tokens
   - Each request consumes 1 token
   - Tokens refill at fixed rate (1/second for 60/min)
   - Burst allowed up to bucket capacity
   
2. Fixed Window Counter:
   - Count requests in current time window (current minute)
   - Reset counter each new window
   - Problem: burst at window boundary (120 req in 2 seconds)

3. Sliding Window Log:
   - Store timestamp of each request
   - Count requests in last N seconds
   - Most accurate, most memory
   
4. Sliding Window Counter:
   - Combines fixed window + sliding window
   - More memory efficient, good accuracy

Implementation with Redis:
  # Token bucket with Redis
  key = f"rate_limit:{user_id}"
  
  # Lua script (atomic)
  script = """
    local tokens = tonumber(redis.call('GET', KEYS[1]) or ARGV[1])
    if tokens < 1 then
      return 0  -- rate limited
    end
    redis.call('SET', KEYS[1], tokens - 1, 'EX', ARGV[2])
    return 1  -- allowed
  """
  
  allowed = redis.eval(script, [key], [max_tokens, window_seconds])

Architecture:
  Request → Rate Limiter Middleware → API Server
  
  Rate Limiter:
    Checks Redis for request count
    If under limit: allow + increment counter
    If over limit: return 429 Too Many Requests
    
  Headers to return:
    X-RateLimit-Limit: 100
    X-RateLimit-Remaining: 45
    X-RateLimit-Reset: 1703001600

  Distributed rate limiting:
    Multiple API servers, central Redis
    Problem: Redis is now a bottleneck
    Solution: Redis Cluster or local rate limit + sync periodically
```

---

## PART 3 — API DESIGN

### REST vs GraphQL vs gRPC

```
REST:
  Protocol: HTTP/1.1
  Format: JSON (typically)
  Operations: GET, POST, PUT, PATCH, DELETE
  Versioning: /api/v1/users, /api/v2/users
  
  Pros:
    Simple, widely understood
    Browser-native (no special client)
    HTTP caching works naturally
    Easy to document (OpenAPI/Swagger)
  
  Cons:
    Over-fetching (endpoint returns more data than needed)
    Under-fetching (need multiple requests for related data)
    API versioning complexity

GraphQL:
  Protocol: HTTP (POST to single endpoint)
  Format: JSON query language
  Client specifies exactly what data it wants
  
  type User {
    id: ID!
    name: String!
    posts: [Post!]!
  }
  
  query {
    user(id: "123") {
      name
      posts { title, createdAt }
    }
  }
  
  Pros:
    No over/under-fetching
    Single request for nested data
    Strong typing and schema
    Great for mobile (bandwidth matters)
  
  Cons:
    Complex server implementation
    N+1 query problem (need DataLoader)
    Caching is harder
    Overkill for simple APIs

gRPC:
  Protocol: HTTP/2
  Format: Protocol Buffers (binary — smaller, faster than JSON)
  Code generation: client libraries generated from .proto files
  Streaming: bidirectional streaming supported
  
  Pros:
    Very fast (binary + HTTP/2)
    Strong typing (proto schema)
    Built-in streaming
    Generated clients in multiple languages
  
  Cons:
    Not human-readable
    Browser support limited
    More complex tooling
  
  Use for: microservice-to-microservice (internal APIs)

When to use what:
  Public API (third parties consume it): REST
  Mobile app with complex data needs: GraphQL
  Internal microservices: gRPC
  Real-time streaming: gRPC or WebSocket
```

### REST API Best Practices

```
URL design:
  /users              GET (list) POST (create)
  /users/{id}         GET PUT DELETE
  /users/{id}/posts   GET (user's posts)
  
  Use nouns not verbs: /users not /getUsers
  Use plural: /users not /user
  Use lowercase with hyphens: /user-profiles not /userProfiles

HTTP status codes:
  200 OK              → successful GET, PUT, PATCH
  201 Created         → successful POST
  204 No Content      → successful DELETE
  400 Bad Request     → invalid input
  401 Unauthorized    → not authenticated
  403 Forbidden       → authenticated but no permission
  404 Not Found       → resource doesn't exist
  409 Conflict        → duplicate resource
  429 Too Many Requests → rate limited
  500 Internal Server Error → server bug
  503 Service Unavailable → server overloaded/down

Pagination:
  Offset: GET /users?page=2&limit=20
    Problem: slow on large datasets (OFFSET 10000 scans 10000 rows)
  
  Cursor: GET /users?cursor=lastId&limit=20
    Efficient: WHERE id > cursor LIMIT 20
    Use for large datasets, real-time data (no duplicate/missing items)

Versioning:
  URL: /api/v1/users (most common, clear)
  Header: Accept: application/vnd.api.v1+json
  Query: /users?version=1 (not recommended)
```

---

## PART 4 — CACHING STRATEGIES

### Caching Layers

```
Browser Cache:
  HTTP cache headers: Cache-Control, ETag, Last-Modified
  Reduces requests to server entirely

CDN (CloudFront, CloudFlare):
  Caches static assets at edge locations globally
  Reduces latency for global users
  Cache: HTML, CSS, JS, images, videos

Application Cache (Redis, Memcached):
  Caches database query results, computed values
  Reduces database load
  In-memory = very fast

Database Cache:
  Query cache (deprecated in MySQL 8)
  Buffer pool (InnoDB) — caches frequently accessed data pages

CPU Cache:
  L1, L2, L3 — managed by OS, not application concern
```

### Cache Strategies

```
Cache-Aside (Lazy Loading) — most common:
  1. App checks cache → miss
  2. App queries database
  3. App stores result in cache
  4. App returns result
  
  Pros: only cache what's requested, resilient (app works without cache)
  Cons: cache miss = 3 operations, stale data possible
  
  def get_user(user_id):
      user = redis.get(f"user:{user_id}")
      if not user:
          user = db.query("SELECT * FROM users WHERE id = ?", user_id)
          redis.setex(f"user:{user_id}", 3600, serialize(user))
      return user

Write-Through:
  Write to cache AND database simultaneously
  Cache always consistent with DB
  
  Pros: no stale data, read always from cache
  Cons: write latency increased, cache may have data never read

Write-Behind (Write-Back):
  Write to cache immediately, write to DB asynchronously
  
  Pros: very fast writes, batch DB writes
  Cons: data loss if cache dies before DB write

Read-Through:
  Cache sits between app and DB
  App always reads from cache
  Cache handles DB population on miss
  
  Like cache-aside but cache manages the population

Refresh-Ahead:
  Proactively refresh cache before expiry
  Use when: access pattern predictable, always need fresh data
```

### Cache Eviction Policies

```
LRU (Least Recently Used):
  Evicts item not accessed for longest time
  Most common policy
  Good for: general purpose caching

LFU (Least Frequently Used):
  Evicts item accessed least number of times
  Good for: popular items that should stay forever

FIFO (First In First Out):
  Evicts oldest cached item
  Simple, not optimal

TTL (Time To Live):
  Item expires after fixed duration
  Simple, predictable
  Use when: data has natural expiry (sessions, tokens)

Cache sizing:
  80/20 rule: 20% of data serves 80% of requests
  Cache top 20% → cache hit rate ~80%
  Start with 16GB Redis, monitor hit rate
  Hit rate < 80% → increase cache size
```

### CDN Strategy

```
Static content:
  CSS, JS, images, videos → cache in CDN indefinitely
  Cache-Control: max-age=31536000, immutable
  Use content hash in filename: app.abc123.js
  → filename changes when content changes
  → cache busted automatically

Dynamic content:
  API responses → cache with short TTL (5-60 seconds)
  User-specific data → don't cache (or cache with user key)
  Cache-Control: no-cache (must revalidate with server)

CloudFront patterns:
  /api/* → no-cache, forward to origin
  /static/* → cache 1 year at edge
  /images/* → cache 1 week at edge

Invalidation:
  CloudFront: aws cloudfront create-invalidation --paths "/*"
  Expensive: $0.005 per 1000 paths after first 1000/month
  Better: use versioned filenames (no invalidation needed)
```

---

## PART 5 — MESSAGE QUEUES + EVENT-DRIVEN ARCHITECTURE

### Why Message Queues?

```
Problem without queues:
  User uploads video
  API calls video processor synchronously
  User waits 5 minutes
  If processor crashes: request fails, user must retry
  If traffic spikes: API overwhelmed

With message queue:
  User uploads video
  API puts message in queue: "process video XYZ"
  API returns 202 Accepted immediately (user not waiting)
  Video processor reads message, processes async
  If processor crashes: message stays in queue, retry
  Traffic spike: messages queue up, processors work at their pace
```

### SQS Deep Dive

```
SQS types:
  Standard Queue:
    - At-least-once delivery (duplicates possible)
    - Best-effort ordering (not guaranteed)
    - Unlimited throughput
    - Use for: most async processing, idempotent consumers

  FIFO Queue:
    - Exactly-once processing (no duplicates)
    - Strict ordering within message group
    - 300 messages/second (3,000 with batching)
    - Use for: order processing, financial transactions

Key concepts:
  Visibility Timeout:
    When consumer receives message, it's hidden from others for N seconds
    If consumer crashes: message becomes visible again after timeout
    If consumer finishes: delete message explicitly
    Default: 30 seconds, max: 12 hours

  Dead Letter Queue (DLQ):
    If message fails maxReceiveCount times → moved to DLQ
    Investigate failed messages without blocking main queue

  Message Retention:
    1 minute to 14 days (default 4 days)

  Long Polling:
    Wait up to 20 seconds for messages
    Reduces empty API calls (cheaper)
    Always use long polling (--wait-time-seconds 20)

Lambda + SQS pattern:
  SQS → Lambda (batch of messages)
  Lambda processes batch
  Successful: SQS auto-deletes
  Failed: returns failed message IDs (batchItemFailures)
  Failed messages: requeued for retry
```

### Kafka vs SQS

```
Apache Kafka:
  Distributed event streaming platform
  Messages stored as log (retained for days/months)
  Multiple consumers can read same messages independently
  High throughput: millions of events/second
  
  Use for:
    - Event sourcing (replay history)
    - Real-time analytics
    - Multiple consumers of same event stream
    - Stream processing (Kafka Streams, Flink)

SQS:
  Managed message queue
  Messages deleted after consumption
  One consumer reads each message
  Up to 120,000 msg/second
  
  Use for:
    - Task queues (each task done once)
    - Decoupling services
    - Serverless architectures (Lambda trigger)

Choose Kafka when:
  Multiple services need to react to same event
  Need to replay events
  Need stream processing
  Very high throughput requirements

Choose SQS when:
  Simple task queue
  AWS-native, serverless
  Don't need replay or multiple consumers
```

### Event-Driven Architecture Patterns

```
Event Sourcing:
  Store events not state
  "User placed order" "Order confirmed" "Order shipped"
  Current state = replay of all events
  
  Benefits: complete audit trail, replay, temporal queries
  Costs: complexity, eventual consistency

CQRS (Command Query Responsibility Segregation):
  Separate read and write models
  Write path: process commands, emit events
  Read path: optimized for queries (denormalized views)
  
  Use when: read and write patterns very different
             heavy read load needs different optimization

Saga Pattern (distributed transactions):
  Long-running transaction across multiple services
  Each step emits event, next step reacts
  Compensating transactions on failure (reverse the steps)
  
  Order service saga:
    1. Reserve inventory → success → emit InventoryReserved
    2. Charge payment → success → emit PaymentCharged
    3. Create shipment → success → emit OrderCompleted
    
    If payment fails:
    Compensate: release inventory reservation
```

---

## PART 6 — DATABASE DESIGN

### SQL vs NoSQL Decision

```
Use SQL (PostgreSQL, MySQL) when:
  Data has clear relationships (foreign keys, joins)
  Need ACID transactions (financial, inventory)
  Schema is stable and well-defined
  Complex queries with joins and aggregations
  Data integrity is critical

Use NoSQL when:
  Massive scale (Twitter, Netflix, Amazon)
  Schema changes frequently or varies per record
  Simple access patterns (get by key, get user's posts)
  Horizontal scaling required
  Document storage (JSON blobs)

NoSQL types:
  Key-Value: Redis, DynamoDB (simple key lookup, caching)
  Document: MongoDB, DynamoDB (JSON documents, flexible schema)
  Column: Cassandra, HBase (time series, analytics, write-heavy)
  Graph: Neo4j (relationships are first-class, social networks)
```

### Database Scaling

```
Vertical scaling:
  Larger instance (more RAM/CPU)
  Simplest, no code changes
  Limit: hardware ceiling

Read Replicas:
  Primary handles writes
  Replicas handle reads
  Replication lag: usually < 1 second
  Use when: read-heavy workload (social media, e-commerce)

Connection Pooling:
  Reuse DB connections (expensive to create)
  PgBouncer for PostgreSQL, RDS Proxy for AWS
  Without pooling: 1000 Lambda = 1000 DB connections → exhausted

Caching:
  Redis/Memcached in front of DB
  80% of reads served from cache
  DB handles only cache misses + all writes

Sharding (horizontal partitioning):
  Split data across multiple DB servers
  Each server holds subset of data
  
  Shard by user_id: user 1-1M on shard-1, 1M-2M on shard-2
  
  Pros: unlimited horizontal scale
  Cons: cross-shard queries hard, resharding painful
  Use when: vertical scaling and read replicas not enough

Federation (functional partitioning):
  Different databases for different features
  Users DB, Orders DB, Products DB — separate servers
  Reduces load per DB
  Cons: joins across databases impossible

CQRS:
  Write to normalized SQL (data integrity)
  Read from denormalized NoSQL (performance)
  Event-driven sync between write and read stores
```

### Database Indexing

```
Index = sorted copy of column data → fast lookups

B-Tree Index (default):
  Good for: equality and range queries
  WHERE email = 'a@b.com'
  WHERE created_at > '2024-01-01'

Composite Index:
  Multiple columns: (user_id, created_at)
  Column order matters: index used for leftmost prefix
  WHERE user_id = 1 → uses index
  WHERE user_id = 1 AND created_at > x → uses index
  WHERE created_at > x → does NOT use index (no user_id prefix)

Covering Index:
  Index includes all columns needed by query
  No need to access actual table rows
  Much faster than regular index

When to index:
  Columns in WHERE clauses
  Columns in JOIN conditions
  Foreign keys
  Columns in ORDER BY (with matching WHERE)

When NOT to index:
  Low cardinality columns (status: active/inactive → few unique values)
  Frequently updated columns (index must be updated on each write)
  Small tables (full scan faster than index lookup)
```

---

## PART 7 — MICROSERVICES ARCHITECTURE

### Decomposition Principles

```
Decompose by Business Capability:
  User Service, Order Service, Payment Service, Inventory Service
  Each team owns one service end-to-end
  
Decompose by Subdomain (Domain-Driven Design):
  Identify bounded contexts
  Each bounded context = one or more services
  Services communicate via well-defined APIs

What makes a good microservice:
  Single Responsibility: does one thing well
  Autonomous: can be deployed independently
  Owns its data: has its own database
  Loosely coupled: minimal dependencies on other services
  Highly cohesive: related functionality together
```

### Service Communication

```
Synchronous (REST/gRPC):
  Service A calls Service B and waits for response
  Simple, immediate response
  Problem: if B is down, A fails (tight coupling)
  Problem: if B is slow, A is slow (cascading latency)
  
  Use for: user-facing requests that need immediate response
           payment confirmation, authentication

Asynchronous (Events/Messages):
  Service A publishes event, doesn't wait
  Service B consumes event when ready
  A and B are decoupled — B being down doesn't affect A
  
  Use for: background processing, notifications, analytics
           anything that doesn't need immediate response

Patterns for service communication:
  API Gateway: single entry point for all external requests
    Routes to correct service
    Handles: auth, rate limiting, SSL termination
    
  Service Mesh (Istio, Linkerd):
    Sidecar proxy handles all network concerns
    mTLS between services automatically
    Observability: traces, metrics per service pair
    Traffic management: retries, circuit breaking
```

### Circuit Breaker Pattern

```
Problem: Service A calls B. B is slow/down.
  A waits for timeout (30s)
  Many requests pile up waiting
  A runs out of threads → A crashes
  Cascading failure: A's failure causes C to fail, etc.

Circuit Breaker:
  CLOSED → requests pass through normally
    track failure rate
    if failures > threshold → OPEN
  
  OPEN → requests fail immediately (no timeout wait)
    no requests sent to B
    after timeout → HALF-OPEN
  
  HALF-OPEN → send limited requests to test B
    if successful → CLOSED
    if failed → back to OPEN

Implementation: Hystrix (Java), Resilience4j, Polly (.NET)

# Python with tenacity
from tenacity import retry, stop_after_attempt, wait_exponential

@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=1, max=10)
)
def call_service_b():
    response = requests.get("http://service-b/api")
    response.raise_for_status()
    return response.json()
```

---

## PART 8 — DESIGN A SERVERLESS PLATFORM (judicialsolutions.in)

### Requirements Clarification

```
Functional:
  - Legal case management platform
  - Users: lawyers, clerks, judges
  - CRUD for cases, documents, hearings
  - Document upload (PDFs, images)
  - Search across cases
  - Real-time notifications

Non-Functional:
  - 10,000 registered users, 1,000 daily active
  - 100 concurrent users peak
  - 99.9% availability
  - Documents up to 50MB
  - Data residency: India (ap-south-1)
  - GDPR-like compliance
```

### Architecture Design

```
                        Internet
                           │
                    ┌──────▼──────┐
                    │  CloudFront  │ ← CDN (static assets + API cache)
                    └──────┬──────┘
                           │
              ┌────────────┴────────────┐
              │                         │
       ┌──────▼──────┐         ┌────────▼────────┐
       │  S3 (Static  │         │  API Gateway    │
       │   Website)   │         │  (HTTP API)     │
       └─────────────┘         └────────┬────────┘
                                         │
                              ┌──────────▼──────────┐
                              │      Lambda          │
                              │  (Python FastAPI)    │
                              └──────────┬──────────┘
                                         │
              ┌──────────────────────────┼──────────────────────────┐
              │                          │                          │
    ┌─────────▼─────────┐    ┌──────────▼──────────┐   ┌──────────▼──────────┐
    │    DynamoDB        │    │   S3 (Documents)    │    │   Cognito           │
    │ (Cases, Users)     │    │                     │    │ (Auth)              │
    └───────────────────┘    └────────────────────┘   └────────────────────┘
              │
    ┌─────────▼─────────┐
    │   SQS + Lambda     │
    │ (Async: email,     │
    │  notifications)    │
    └───────────────────┘
```

### Component Deep Dive

```
API Layer (API Gateway + Lambda):
  HTTP API Gateway (cheaper, lower latency than REST API)
  Lambda: Python FastAPI, 256MB memory, 30s timeout
  Lambda warmed via scheduled EventBridge rule
  
  Endpoints:
    POST /auth/login → Cognito
    GET /cases → list cases (paginated with cursor)
    POST /cases → create case
    GET /cases/{id} → get case details
    POST /cases/{id}/documents → upload document (presigned S3 URL)
    GET /cases/{id}/documents → list documents

Document Upload Flow:
  Client → POST /documents/presigned-url
  Lambda → generates S3 presigned URL (15 min expiry)
  Client → PUT directly to S3 (bypasses API Gateway size limit)
  S3 → triggers Lambda (post-upload processing)
  Lambda → extract text, generate thumbnail, update DynamoDB

Authentication:
  Cognito User Pool: handles signup, login, MFA, token refresh
  JWT tokens: verified by API Gateway before Lambda invocation
  Lambda Authorizer: custom auth for fine-grained access control

Database Design (DynamoDB):
  Single table design (partition efficiently)
  
  PK              SK                Entity
  USER#u123       #METADATA         User
  CASE#c456       #METADATA         Case
  CASE#c456       DOC#d789          Document
  CASE#c456       HEARING#h000      Hearing
  USER#u123       CASE#c456         User-Case mapping
  
  Access patterns:
    Get user: PK=USER#u123, SK=#METADATA
    Get case: PK=CASE#c456, SK=#METADATA
    Get case docs: PK=CASE#c456, SK begins_with DOC#
    Get user's cases: GSI1 (email → case list)

Search:
  Option 1: DynamoDB scan with filter (simple but slow at scale)
  Option 2: OpenSearch Service (full-text search, facets)
    DynamoDB Streams → Lambda → OpenSearch index

Notification System:
  Case update → Lambda → SQS → Lambda → SNS → Email/SMS
  Real-time: WebSocket API Gateway + DynamoDB (connection store)

Cost estimation (1000 DAU):
  Lambda: 1000 users * 50 requests * $0.0000002 = ~$0.01/day
  DynamoDB: on-demand, ~$5/month for this scale
  S3: 1TB storage = $23/month
  CloudFront: 100GB/month = $8.50/month
  Cognito: first 50K MAU free
  Total: ~$50-100/month (vs EC2: $200-500/month for equivalent)
```

### Infrastructure as Code

```hcl
# Complete Terraform for this architecture
module "vpc" {
  source = "./modules/vpc"
  # Lambda in VPC for RDS access (if needed)
}

module "cognito" {
  source = "./modules/cognito"
  user_pool_name = "judicial-users-${var.env}"
}

module "api" {
  source = "./modules/api_gateway"
  cognito_user_pool_arn = module.cognito.user_pool_arn
}

module "lambda" {
  source = "./modules/lambda"
  api_gateway_id = module.api.id
}

module "dynamodb" {
  source = "./modules/dynamodb"
  # Lambda gets least-privilege access only
}

module "s3" {
  source = "./modules/s3"
  # Private bucket, presigned URLs for access
}

module "cloudfront" {
  source = "./modules/cloudfront"
  api_gateway_endpoint = module.api.endpoint
  s3_website_bucket = module.s3.website_bucket
}
```

---

## PART 9 — DESIGN A CI/CD PLATFORM END TO END

### Requirements

```
Functional:
  - Developers push code → tests run → deploy to staging → deploy to prod
  - Multiple languages (Python, Node, Go, Java)
  - Multiple environments (dev, staging, prod)
  - Rollback capability
  - Build history and logs
  - Branch-based workflows

Non-Functional:
  - 100 developers, 50 repos
  - Build time < 10 minutes
  - 99.9% pipeline availability
  - Secure: secrets management, RBAC
```

### Architecture

```
Developer pushes code to GitHub
    │
    │ Webhook
    ▼
GitHub Actions / Jenkins
    │
    ├── Stage 1: Code Quality
    │   ├── Linting (flake8, eslint)
    │   ├── Unit tests
    │   └── Code coverage check
    │
    ├── Stage 2: Build
    │   ├── Build Docker image
    │   ├── Scan image (Trivy)
    │   └── Push to ECR (tagged with git SHA)
    │
    ├── Stage 3: Integration Tests
    │   ├── Spin up dependencies (docker-compose)
    │   ├── Run integration tests
    │   └── Tear down
    │
    ├── Stage 4: Deploy to Staging (auto)
    │   ├── Update ECS/EKS task definition
    │   ├── Rolling deployment
    │   ├── Smoke tests
    │   └── Slack notification
    │
    └── Stage 5: Deploy to Production (manual approval)
        ├── Approval gate (GitHub Environments)
        ├── Blue-green deployment
        ├── Smoke tests
        ├── Rollback if smoke fails
        └── Slack notification
```

### Pipeline Design Decisions

```
Artifact storage:
  Docker images: ECR (immutable tags = git SHA)
  Build artifacts: S3 (zip files, compiled binaries)
  Test reports: S3 (HTML reports, JUnit XML)
  Tag strategy: myapp:abc1234 (git SHA, immutable)

Secrets management:
  Never in pipeline code
  GitHub: GitHub Secrets (encrypted, scoped)
  AWS: Secrets Manager, accessed via IRSA/OIDC
  Rotation: Secrets Manager handles automatically

Environment promotion:
  dev:     push to any branch → auto-deploy
  staging: push to main → auto-deploy after tests
  prod:    push to main → manual approval required
  
  Same Docker image promoted (not rebuilt per environment)
  Configuration injected at runtime (not baked into image)

Rollback strategy:
  Kubernetes: kubectl rollout undo (instant, no image pull)
  ECS: update task definition to previous image tag
  Lambda: update function to previous version alias
  
  Keep last 5 image versions in ECR
  Rollback = re-deploy previous SHA

Observability:
  Build metrics: duration, success rate per repo
  Deployment metrics: frequency, lead time, failure rate (DORA)
  Alerts: failed builds, long build times, failed deployments
```

### GitHub Actions Complete Pipeline

```yaml
name: Complete CI/CD

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: {python-version: '3.12'}
      - run: pip install flake8 pytest coverage
      - run: flake8 src/
      - run: coverage run -m pytest
      - run: coverage report --fail-under=80

  build:
    needs: quality
    runs-on: ubuntu-latest
    outputs:
      image_tag: ${{ steps.meta.outputs.tags }}
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ap-south-1
      - uses: aws-actions/amazon-ecr-login@v2
      - name: Build and push
        id: meta
        run: |
          IMAGE="${{ secrets.ECR_REGISTRY }}/myapp"
          TAG="${{ github.sha }}"
          docker build -t $IMAGE:$TAG .
          docker push $IMAGE:$TAG
          echo "tags=$IMAGE:$TAG" >> $GITHUB_OUTPUT
      - name: Scan
        run: |
          trivy image --exit-code 1 \
            --severity CRITICAL \
            ${{ steps.meta.outputs.tags }}

  deploy-staging:
    needs: build
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.STAGING_ROLE_ARN }}
          aws-region: ap-south-1
      - name: Deploy to EKS
        run: |
          aws eks update-kubeconfig --name staging-cluster
          kubectl set image deployment/myapp \
            app=${{ needs.build.outputs.image_tag }}
          kubectl rollout status deployment/myapp --timeout=5m
      - name: Smoke test
        run: |
          URL=$(kubectl get svc myapp -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
          curl -f http://$URL/health || exit 1

  deploy-prod:
    needs: [build, deploy-staging]
    runs-on: ubuntu-latest
    environment: production  # requires manual approval
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Deploy to production
        run: |
          aws eks update-kubeconfig --name prod-cluster
          kubectl set image deployment/myapp \
            app=${{ needs.build.outputs.image_tag }}
          kubectl rollout status deployment/myapp --timeout=10m
      - name: Smoke test
        run: curl -f https://api.judicialsolutions.in/health || exit 1
      - name: Rollback on failure
        if: failure()
        run: kubectl rollout undo deployment/myapp
```

---

## PART 10 — HIGH AVAILABILITY + DISASTER RECOVERY

### HA Architecture Principles

```
Eliminate Single Points of Failure:
  Load Balancers: min 2 (active-active)
  App Servers: min 3 (survive 1 failure + rolling deploy)
  Databases: primary + replica(s)
  Availability Zones: deploy across min 2 AZs

Health Checks + Auto-Recovery:
  Load balancer removes unhealthy instances
  Auto Scaling replaces failed EC2s
  ECS/EKS replaces failed containers
  RDS: automated failover to replica (< 60 seconds)

Data Redundancy:
  S3: 99.999999999% durability (11 nines)
  RDS Multi-AZ: synchronous replication to standby
  DynamoDB: automatically replicated across 3 AZs

Graceful Degradation:
  If recommendation service down → show default recommendations
  If search down → show "search unavailable" not blank page
  Circuit breaker: fail fast, don't wait for timeout
```

### Recovery Objectives

```
RTO (Recovery Time Objective):
  How long can the system be down?
  RTO = 4 hours → system must be back in 4 hours
  Lower RTO = more expensive (hot standby vs cold backup)

RPO (Recovery Point Objective):
  How much data loss is acceptable?
  RPO = 1 hour → might lose up to 1 hour of data
  RPO = 0 → no data loss acceptable (synchronous replication)

DR strategies (cost vs recovery time):

Backup and Restore (cheapest):
  RTO: hours, RPO: hours
  Backup everything to S3
  In disaster: restore from backup
  
Pilot Light:
  RTO: 10-30 min, RPO: minutes
  Core services running at minimal scale in DR region
  Data replicated (RDS read replica, DynamoDB global tables)
  In disaster: scale up DR region quickly

Warm Standby:
  RTO: minutes, RPO: seconds
  Full copy running at reduced capacity
  Failing over: update DNS, scale up
  
Active-Active (most expensive):
  RTO: seconds, RPO: near-zero
  Both regions serving traffic
  Global load balancing (Route53 latency routing)
  Data: synchronous replication (expensive and complex)
```

### Multi-Region Architecture

```
Primary Region (ap-south-1):
  ┌─────────────────────────────────┐
  │ Route53 (DNS)                   │
  │ CloudFront (CDN)                │
  │ ALB → EKS Pods                  │
  │ RDS Primary                     │
  │ DynamoDB                        │
  └─────────────────────────────────┘
           │ replication
           ▼
DR Region (ap-southeast-1):
  ┌─────────────────────────────────┐
  │ ALB → EKS Pods (scaled down)   │
  │ RDS Read Replica                │
  │ DynamoDB Global Table           │
  └─────────────────────────────────┘

Failover:
  1. Detect primary region failure (health check)
  2. Route53 health check fails → update DNS to DR region
  3. Promote RDS replica to primary
  4. Scale up EKS in DR region
  5. Total time: 5-15 minutes (RTO)
  6. RPO: seconds (synchronous RDS replication)
```

### AWS Well-Architected Framework

```
5 Pillars (memorise these):

1. Operational Excellence:
   Infrastructure as Code (Terraform)
   CI/CD pipelines
   Runbooks for incidents
   Post-incident reviews

2. Security:
   Least privilege IAM
   Encryption at rest and in transit
   VPC, security groups, NACLs
   CloudTrail for audit

3. Reliability:
   Multi-AZ deployments
   Auto Scaling
   Health checks and auto-recovery
   Disaster recovery planning

4. Performance Efficiency:
   Right-size instances
   Caching (CDN, Redis)
   Serverless for variable workloads
   Monitor and optimize

5. Cost Optimization:
   Right-sizing (VPA, CloudWatch)
   Spot instances for batch
   Reserved instances for predictable workloads
   Delete unused resources
   S3 lifecycle policies
```

---

## SYSTEM DESIGN INTERVIEW — HOW TO ANSWER

### Step-by-Step Framework (45-minute interview)

```
Minutes 0-5: Clarify Requirements
  "Before I start, let me clarify a few things..."
  
  Functional:
    What are the core use cases?
    Who are the users?
    What scale (10K users or 100M)?
  
  Non-Functional:
    Read-heavy or write-heavy?
    Availability requirement (99.9%? 99.99%?)
    Latency requirement (p99 < 100ms?)
    Data consistency requirements?

Minutes 5-10: Estimation
  Users → requests per second
  Storage requirements
  Bandwidth requirements
  
  "With 1M users, 10 requests/day each = ~115 req/sec average,
   350 req/sec peak. Storage: 1M users * 1KB = 1GB for user data."

Minutes 10-20: High-Level Design
  Draw boxes: clients, load balancer, services, databases, cache
  Show main data flow
  Don't dive deep yet
  
  "At high level: client → CloudFront → ALB → API servers → cache → DB"

Minutes 20-40: Deep Dive
  Pick 2-3 most critical/interesting components
  Go deep on: database schema, caching strategy, scaling approach
  Address bottlenecks proactively

Minutes 40-45: Bottlenecks + Tradeoffs
  "The bottleneck here is..."
  "I chose DynamoDB over RDS because..."
  "One thing I'd improve is..."
```

### Common Follow-up Questions

```
"How would you scale to 10x traffic?"
  → Horizontal scaling, caching, DB read replicas, CDN

"What if the database goes down?"
  → Read replicas, multi-AZ, circuit breaker, graceful degradation

"How do you handle data consistency?"
  → CAP theorem tradeoff, eventual consistency, transactions

"How do you monitor this system?"
  → Metrics (CloudWatch/Prometheus), logs (ELK), traces (X-Ray)
  → SLOs: p99 latency < 200ms, error rate < 0.1%, availability > 99.9%

"What's your single biggest risk?"
  → Shows you understand the design's weakness
  → "The DynamoDB hot partition for popular items — I'd add ElastiCache"
```

---

## QUICK REFERENCE — COMPONENT SELECTION

```
Load Balancer:
  HTTP/HTTPS: AWS ALB, Nginx
  TCP/UDP high throughput: AWS NLB
  Between microservices: service mesh (Istio)

Database:
  ACID transactions: PostgreSQL, RDS
  Key-value, massive scale: DynamoDB
  Time series: InfluxDB, Timestream
  Full-text search: OpenSearch/Elasticsearch
  Graph: Neptune, Neo4j
  Analytics: Redshift, Athena

Cache:
  In-memory cache: Redis (rich data structures, persistence)
  Simple cache: Memcached (simpler, faster for basic use)
  CDN: CloudFront, CloudFlare

Message Queue:
  Simple task queue, AWS-native: SQS
  Event streaming, multiple consumers: Kafka, Kinesis
  Pub/sub: SNS, Redis Pub/Sub

File Storage:
  Object storage: S3 (static files, backups, archives)
  Block storage: EBS (databases, OS volumes)
  File system: EFS (shared file system, NFS)
  CDN: CloudFront (serve static assets globally)

Compute:
  Containerised apps: EKS, ECS
  Serverless: Lambda
  Simple VM: EC2
  Batch processing: AWS Batch, Fargate

Monitoring:
  Metrics: CloudWatch, Prometheus + Grafana
  Logs: ELK Stack, CloudWatch Logs, Loki
  Traces: AWS X-Ray, Jaeger, Tempo
  Uptime: Route53 health checks, Pingdom
```
