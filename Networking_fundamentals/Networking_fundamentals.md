# Networking Fundamentals — Complete Deep Dive
## OSI + TCP/IP + DNS + HTTP + Load Balancing + Troubleshooting
### Theory → Hands-on → Interview Questions

---

## README

**Total sections:** 10
**Target:** Mid-level to Senior DevOps/Cloud Engineer interviews
**Coverage:** Everything from fundamentals to real DevOps scenarios

### Priority sections:
| Section | Why it matters |
|---|---|
| Part 1 — OSI Model | Every interview starts here |
| Part 3 — DNS | "How does DNS work?" — asked in 90% of DevOps interviews |
| Part 4 — HTTP/HTTPS | API debugging, TLS, certificate issues |
| Part 5 — Load Balancing | L4 vs L7 — directly on your resume |
| Part 9 — Troubleshooting | "Container can't reach DB" — real-world debugging |

### Power phrases:
- *"OSI has 7 layers — for interviews, focus on L3 (IP/routing), L4 (TCP/UDP/ports), L7 (HTTP/application)"*
- *"DNS is recursive — client → resolver → root → TLD → authoritative"*
- *"L4 load balancer routes by IP+port, L7 routes by HTTP content (path, host, header)"*
- *"TCP is reliable but slow (3-way handshake), UDP is fast but unreliable"*
- *"TLS handshake: cipher negotiation → certificate → key exchange → symmetric encryption"*

---

## 📌 TABLE OF CONTENTS

| # | Section | Key Topics |
|---|---|---|
| 1 | [OSI Model + TCP/IP](#part-1--osi-model--tcpip-fundamentals) | 7 layers, what happens at each layer |
| 2 | [IP Addressing + CIDR](#part-2--ip-addressing-cidr-subnetting) | IPv4/IPv6, subnetting, CIDR notation |
| 3 | [DNS](#part-3--dns) | Resolution flow, record types, TTL, caching |
| 4 | [HTTP/HTTPS](#part-4--httphttps) | Methods, status codes, headers, TLS handshake |
| 5 | [Load Balancing](#part-5--load-balancing) | L4 vs L7, algorithms, health checks, ALB vs NLB |
| 6 | [TCP vs UDP](#part-6--tcp-vs-udp) | 3-way handshake, reliability, when to use each |
| 7 | [Firewalls + Proxies](#part-7--firewalls-proxies-reverse-proxies) | Stateful/stateless, forward/reverse proxy, Nginx |
| 8 | [CDN Fundamentals](#part-8--cdn-fundamentals) | Edge caching, CloudFront, cache invalidation |
| 9 | [Network Troubleshooting](#part-9--network-troubleshooting) | ping, traceroute, netstat, curl, tcpdump |
| 10 | [DevOps Networking Scenarios](#part-10--common-devops-networking-scenarios) | "Why can't X reach Y?" — real scenarios |

---

## PART 1 — OSI MODEL + TCP/IP FUNDAMENTALS

### The OSI Model — 7 Layers

```
Layer 7 — Application
  What: HTTP, HTTPS, DNS, FTP, SMTP, WebSocket
  What happens: application-specific protocol
  Your code lives here. API requests, web pages.

Layer 6 — Presentation
  What: encryption, encoding, compression
  What happens: TLS/SSL encryption, data format conversion
  In practice: often merged with Layer 7

Layer 5 — Session
  What: establish, maintain, terminate sessions
  What happens: session management between applications
  In practice: often merged with Layer 7

Layer 4 — Transport
  What: TCP, UDP
  What happens: port numbers, reliable delivery (TCP) or fast (UDP)
  Firewalls work here — filter by port and protocol
  Load balancers work here (L4) or Layer 7 (L7)

Layer 3 — Network
  What: IP, ICMP, routing protocols (OSPF, BGP)
  What happens: IP addressing, routing between networks
  Routers work at this layer
  AWS route tables work here

Layer 2 — Data Link
  What: Ethernet, Wi-Fi (802.11), ARP, MAC addresses
  What happens: frame transmission between directly connected devices
  Switches work at this layer

Layer 1 — Physical
  What: cables, signals, radio waves
  What happens: actual bit transmission
  Ethernet cables, fiber optic, wireless signals

Memory trick: "All People Seem To Need Data Processing"
  Application → Presentation → Session → Transport → Network → Data Link → Physical
```

### What Happens When You Type a URL

```
User types: https://judicialsolutions.in/cases

Step 1: DNS resolution (L7)
  Browser checks local cache → OS cache → Router cache
  If no cache: query DNS resolver (usually your ISP or 8.8.8.8)
  Resolver asks root servers → TLD (.in) → authoritative
  Returns: IP address of judicialsolutions.in (e.g. 13.35.12.45)

Step 2: TCP connection (L4)
  Browser initiates 3-way handshake with 13.35.12.45:443
  SYN → SYN-ACK → ACK

Step 3: TLS handshake (L6/L7)
  Client Hello → Server Hello + Certificate
  Key exchange → session keys established
  All subsequent data encrypted

Step 4: HTTP request (L7)
  GET /cases HTTP/1.1
  Host: judicialsolutions.in
  Authorization: Bearer <token>

Step 5: Response
  Server processes, responds:
  HTTP/1.1 200 OK
  Content-Type: application/json
  {"cases": [...]}

Step 6: TCP teardown (L4)
  FIN → FIN-ACK → ACK → FIN → ACK
  Connection closed (or kept alive for reuse)
```

### TCP/IP Model (4 layers — practical version)

```
Application Layer:  HTTP, DNS, SMTP, SSH (OSI L5-L7)
Transport Layer:    TCP, UDP             (OSI L4)
Internet Layer:     IP, ICMP, ARP        (OSI L3)
Network Access:     Ethernet, Wi-Fi      (OSI L1-L2)

TCP/IP is what actually runs on the internet.
OSI is the conceptual model used for learning and troubleshooting.
In interviews: know OSI layers, but understand TCP/IP is what's real.
```

---

## PART 2 — IP ADDRESSING, CIDR, SUBNETTING

### IPv4 Basics

```
IPv4 address: 32-bit number, written as 4 octets
  192.168.1.100
  Each octet: 0-255
  Total possible: 2^32 = ~4.3 billion addresses

Classes (historical — not used in modern routing, but still in interviews):
  Class A: 1.0.0.0   - 126.0.0.0   /8  (16M hosts per network)
  Class B: 128.0.0.0 - 191.255.0.0 /16 (65K hosts per network)
  Class C: 192.0.0.0 - 223.255.255.0 /24 (254 hosts per network)
  Class D: 224.0.0.0 - 239.255.255.255 (multicast)
  Class E: 240.0.0.0 - 255.255.255.255 (reserved)

Private ranges (RFC 1918 — not routable on internet):
  10.0.0.0/8       → 16,777,216 addresses (large enterprises, AWS VPCs)
  172.16.0.0/12    → 1,048,576 addresses  (Docker default: 172.17.0.0/16)
  192.168.0.0/16   → 65,536 addresses     (home networks)

Special addresses:
  127.0.0.1         → loopback (localhost)
  0.0.0.0           → all interfaces (bind to all)
  255.255.255.255   → broadcast
  169.254.0.0/16    → link-local (APIPA — no DHCP available)
                      AWS instance metadata: 169.254.169.254
```

### CIDR Notation

```
CIDR (Classless Inter-Domain Routing):
  Format: IP/prefix-length
  Prefix: how many bits are the network portion
  Host bits: remaining bits for host addresses

Examples:
  10.0.0.0/8   → first 8 bits fixed  → 2^24 = 16,777,216 addresses
  10.0.0.0/16  → first 16 bits fixed → 2^16 = 65,536 addresses
  10.0.0.0/24  → first 24 bits fixed → 2^8  = 256 addresses (254 usable)
  10.0.0.0/32  → all 32 bits fixed   → 1 address (specific host)
  0.0.0.0/0    → no bits fixed       → all addresses (default route)

Quick CIDR reference:
  /32 → 1 host           /27 → 32 hosts      /22 → 1,024 hosts
  /31 → 2 hosts (P2P)    /26 → 64 hosts      /21 → 2,048 hosts
  /30 → 4 hosts (2 usable)/25 → 128 hosts    /20 → 4,096 hosts
  /29 → 8 hosts          /24 → 256 hosts     /19 → 8,192 hosts
  /28 → 16 hosts         /23 → 512 hosts     /16 → 65,536 hosts
                                             /8  → 16,777,216 hosts

AWS specifics:
  AWS reserves 5 IPs per subnet (first 4 + last)
  /28 = 16 IPs → 11 usable (smallest practical AWS subnet)
  /24 = 256 IPs → 251 usable (common for subnets)
  /16 = 65,536 IPs → 65,531 usable (common for VPCs)
```

### Subnetting — How to Calculate

```
Given: 10.0.0.0/16, need 4 subnets of equal size

Step 1: How many bits for 4 subnets? 
  2^2 = 4 → need 2 extra bits → /16 + 2 = /18

Step 2: Each subnet size?
  /18 = 32 - 18 = 14 host bits → 2^14 = 16,384 addresses

Step 3: Subnets:
  10.0.0.0/18    → 10.0.0.0 to 10.0.63.255
  10.0.64.0/18   → 10.0.64.0 to 10.0.127.255
  10.0.128.0/18  → 10.0.128.0 to 10.0.191.255
  10.0.192.0/18  → 10.0.192.0 to 10.0.255.255

Practical AWS VPC design (10.0.0.0/16 → 3 AZs × 3 tiers):
  Public  AZ-1a: 10.0.0.0/24   (256 IPs — for ALBs, NAT GW)
  Public  AZ-1b: 10.0.1.0/24
  Public  AZ-1c: 10.0.2.0/24
  Private AZ-1a: 10.0.10.0/24  (256 IPs — for app servers)
  Private AZ-1b: 10.0.11.0/24
  Private AZ-1c: 10.0.12.0/24
  Data    AZ-1a: 10.0.20.0/24  (256 IPs — for RDS, ElastiCache)
  Data    AZ-1b: 10.0.21.0/24
  Data    AZ-1c: 10.0.22.0/24
```

### IPv6 Basics

```
IPv6: 128-bit address (vs IPv4's 32-bit)
  Written as 8 groups of 4 hex digits:
  2001:0db8:85a3:0000:0000:8a2e:0370:7334
  Shortened: 2001:db8:85a3::8a2e:370:7334  (:: = consecutive zeros)

Key differences from IPv4:
  No NAT needed (enough addresses for every device)
  No broadcast (uses multicast instead)
  Built-in IPsec support
  Auto-configuration (no DHCP needed)
  
Special IPv6 addresses:
  ::1          → loopback (like 127.0.0.1)
  fe80::/10    → link-local (like 169.254.0.0/16)
  ::/0         → default route (like 0.0.0.0/0)
  
In AWS:
  AWS assigns /56 IPv6 CIDR to VPCs
  /64 per subnet (fixed — not configurable)
  ALL IPv6 addresses are public (use Egress-Only IGW for private instances)
```

---

## PART 3 — DNS

### DNS Resolution Flow

```
User types: judicialsolutions.in

1. Browser DNS cache
   Check: chrome://net-internals/#dns
   If found → done
   Cache TTL: defined by DNS record

2. OS DNS cache (hosts file first)
   Check: /etc/hosts (Linux) or C:\Windows\System32\drivers\etc\hosts
   Check: OS resolver cache
   If found → done

3. Recursive Resolver (your DNS server)
   Usually: ISP resolver, or 8.8.8.8 (Google), or 1.1.1.1 (Cloudflare)
   This resolver does the heavy lifting

4. Root Name Servers (13 globally, lettered A-M)
   Resolver asks: "who handles .in?"
   Root responds: "here are the .in TLD servers"

5. TLD Name Server (.in registry)
   Resolver asks: "who handles judicialsolutions.in?"
   TLD responds: "here are Route53's authoritative servers: ns-123.awsdns-12.com"

6. Authoritative Name Server (Route53 in your case)
   Resolver asks: "what's the A record for judicialsolutions.in?"
   Route53 responds: "13.35.12.45, TTL=300"

7. Resolver caches the response (for TTL seconds)
   Returns answer to client

8. Client caches (for TTL seconds)
   Browser connects to 13.35.12.45

Total time: 50-200ms for full resolution
            Subsequent requests: 0ms (served from cache until TTL expires)
```

### DNS Record Types

```
A Record:
  Maps hostname → IPv4 address
  example.com → 1.2.3.4
  Use for: any hostname that needs an IP
  
AAAA Record:
  Maps hostname → IPv6 address
  example.com → 2001:db8::1
  
CNAME (Canonical Name):
  Maps hostname → another hostname (alias)
  www.example.com → example.com
  CANNOT be used at apex/root domain (example.com itself)
  Do NOT use for: apex domain, pointing to IP
  
  CNAME chain (avoid):
  a.com → b.com → c.com → 1.2.3.4
  Each hop = extra DNS lookup = slower
  
ALIAS / ANAME (AWS Route53 specific):
  Like CNAME but CAN be used at apex domain
  Maps hostname → another hostname (but resolves to IP)
  No extra TTL hop (resolves immediately)
  Use for: CloudFront, ALB, API Gateway at root domain
  Free queries (unlike external IP lookups)
  
  example.com → ALIAS → d1234.cloudfront.net → (CloudFront IP)
  
MX (Mail Exchange):
  Specifies mail server for domain
  Has priority (lower = preferred)
  @example.com → mail.example.com (priority 10)
  
TXT (Text):
  Arbitrary text (used for verification, SPF, DKIM, DMARC)
  Domain verification: "google-site-verification=abc123"
  SPF: "v=spf1 include:_spf.google.com ~all"
  
NS (Name Server):
  Which servers are authoritative for this domain
  example.com NS → ns-123.awsdns-12.com
  
SOA (Start of Authority):
  Primary name server, admin email, serial number, timing
  Every zone has exactly one SOA record
  
PTR (Pointer):
  Reverse DNS: IP → hostname
  1.2.3.4 → example.com
  Used by: email servers (spam prevention), security tools
  
SRV (Service):
  Specify port and hostname for service
  _http._tcp.example.com → priority weight port target
  Used by: Kubernetes service discovery, SIP, XMPP
```

### TTL and Caching Strategy

```
TTL (Time To Live):
  How long DNS resolvers cache the record (in seconds)
  Low TTL:  changes propagate faster, more DNS queries (more cost/load)
  High TTL: changes propagate slower, fewer DNS queries (cheaper)

Common TTL values:
  30s - 60s:   during migrations (fast propagation, but high query rate)
  300s (5min): balanced — default for many services
  3600s (1hr): stable records (A records, MX)
  86400 (1day):very stable records (NS records)

Migration strategy:
  Before migration:
    Lower TTL to 60s (48 hours before cutover)
    Wait for old TTL to expire everywhere
  
  During migration:
    Change DNS record to new IP/endpoint
    Low TTL = propagates in 60 seconds
  
  After migration:
    Raise TTL back to 300+ for efficiency

DNS propagation myth:
  "DNS takes 24-48 hours to propagate" — this is about TTL
  If TTL was high (86400), cached answers last 24 hours
  With low TTL (60s), propagation is nearly instant
  
  Real propagation: new records appear globally in seconds
  Staleness: cached records live until their TTL expires
```

### Hands-on DNS Commands

```bash
# Basic DNS lookup
dig judicialsolutions.in
dig judicialsolutions.in A         # specific record type
dig judicialsolutions.in MX        # mail records
dig judicialsolutions.in NS        # name servers
dig judicialsolutions.in TXT       # text records

# Trace full resolution path
dig +trace judicialsolutions.in    # shows each step: root → TLD → auth

# Query specific DNS server
dig @8.8.8.8 judicialsolutions.in  # use Google DNS
dig @1.1.1.1 judicialsolutions.in  # use Cloudflare DNS

# Reverse DNS lookup
dig -x 13.35.12.45

# Check TTL (show cached TTL remaining)
dig +noall +answer judicialsolutions.in
# Output: judicialsolutions.in. 287 IN A 13.35.12.45
#                               ^^^  TTL remaining in seconds

# nslookup (simpler, Windows-friendly)
nslookup judicialsolutions.in
nslookup judicialsolutions.in 8.8.8.8

# Check /etc/hosts (local overrides)
cat /etc/hosts

# Clear DNS cache
# Linux (systemd-resolved):
sudo systemctl restart systemd-resolved
# macOS:
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
# Windows:
ipconfig /flushdns
```

---

## PART 4 — HTTP/HTTPS

### HTTP Methods

```
GET:     Retrieve resource. No body. Safe + idempotent.
         GET /cases/123 → returns case data

POST:    Create resource. Has body. Not idempotent.
         POST /cases → creates new case, returns 201

PUT:     Replace resource. Has body. Idempotent.
         PUT /cases/123 → replaces entire case record

PATCH:   Partial update. Has body.
         PATCH /cases/123 → updates specific fields only

DELETE:  Remove resource. Usually no body. Idempotent.
         DELETE /cases/123 → removes case, returns 204

HEAD:    Like GET but returns headers only, no body.
         Use for: check if resource exists, get content-length

OPTIONS: Returns allowed methods for resource.
         Used by browser for CORS preflight check

Safe:       GET, HEAD, OPTIONS — no side effects
Idempotent: GET, PUT, DELETE, HEAD — same result if called multiple times
            POST is NOT idempotent — multiple calls create multiple resources
```

### HTTP Status Codes

```
1xx — Informational:
  100 Continue: send the request body (large POST)

2xx — Success:
  200 OK:         GET, PUT success — body contains resource
  201 Created:    POST success — new resource created
  204 No Content: DELETE success — no body
  206 Partial Content: range request (video streaming)

3xx — Redirection:
  301 Moved Permanently: permanent redirect — browser caches forever
  302 Found:             temporary redirect — don't cache
  304 Not Modified:      cached version still valid (conditional GET)
  307 Temporary Redirect: like 302 but preserves HTTP method
  308 Permanent Redirect: like 301 but preserves HTTP method

4xx — Client Error:
  400 Bad Request:    malformed request, invalid JSON
  401 Unauthorized:   not authenticated (no/invalid token)
  403 Forbidden:      authenticated but no permission
  404 Not Found:      resource doesn't exist
  405 Method Not Allowed: wrong HTTP method
  409 Conflict:       duplicate resource, version conflict
  429 Too Many Requests: rate limited
  422 Unprocessable Entity: valid format but semantic errors

5xx — Server Error:
  500 Internal Server Error: unhandled server exception
  502 Bad Gateway:          upstream returned invalid response
                            (Nginx can't reach your app)
  503 Service Unavailable:  server overloaded or down
                            (health check failing, too many requests)
  504 Gateway Timeout:      upstream too slow
                            (app didn't respond in time)

DevOps gotchas:
  502 from ALB → target health check failing or app returning invalid HTTP
  503 from ALB → no healthy targets in target group
  504 from ALB → target responded but took too long (increase timeout)
```

### HTTP Headers

```
Request headers:
  Host:           judicialsolutions.in (required in HTTP/1.1)
  Authorization:  Bearer <token> | Basic <base64>
  Content-Type:   application/json | multipart/form-data
  Accept:         application/json (what response formats I accept)
  User-Agent:     Mozilla/5.0 ... (client identification)
  Cookie:         session=abc123
  X-Request-ID:   correlation ID for tracing
  X-Forwarded-For: original client IP (when behind proxy/LB)
  If-None-Match:  ETag for conditional GET (cache validation)

Response headers:
  Content-Type:       application/json; charset=utf-8
  Content-Length:     1234 (bytes)
  Cache-Control:      max-age=3600, public | no-cache | no-store
  Set-Cookie:         session=abc123; HttpOnly; Secure; SameSite=Strict
  ETag:               "abc123" (resource version for caching)
  Location:           /cases/123 (redirect target or created resource URL)
  Access-Control-Allow-Origin: * (CORS — who can call this API)
  Strict-Transport-Security: max-age=31536000 (HSTS — force HTTPS)
  X-Content-Type-Options: nosniff (prevent MIME sniffing attacks)

Security headers to always include:
  Strict-Transport-Security: max-age=31536000; includeSubDomains
  X-Frame-Options: DENY
  X-Content-Type-Options: nosniff
  Content-Security-Policy: default-src 'self'
  Referrer-Policy: strict-origin-when-cross-origin
```

### TLS/HTTPS Handshake

```
HTTP = plaintext → anyone can read
HTTPS = HTTP + TLS encryption → encrypted, authenticated

TLS 1.3 Handshake (simplified):

Client → Server: ClientHello
  Supported TLS versions
  Supported cipher suites (e.g., AES-256-GCM)
  Random bytes (client random)

Server → Client: ServerHello + Certificate + ServerHelloDone
  Selected cipher suite
  Server's SSL certificate (public key + signed by CA)
  Random bytes (server random)

Client verifies certificate:
  Is it signed by a trusted CA? (browser has list of trusted CAs)
  Is the hostname matching? (judicialsolutions.in)
  Is it expired? (check NotAfter date)
  Is it revoked? (OCSP check)

Client → Server: Pre-master secret (encrypted with server's public key)
  Only server can decrypt (has private key)

Both sides derive session keys from:
  client random + server random + pre-master secret
  = same session key on both sides

All subsequent data encrypted with symmetric session key
  AES-256-GCM: fast symmetric encryption (unlike slow asymmetric)

Certificates:
  DV (Domain Validation): just proves you own the domain
  OV (Organization Validation): also validates company identity
  EV (Extended Validation): strict validation, green bar (old)
  Wildcard: *.judicialsolutions.in → covers all subdomains
  SAN (Subject Alternative Name): multiple domains in one cert

cert-manager in Kubernetes: automates cert issuance from Let's Encrypt
ACM (AWS Certificate Manager): free certs, auto-renew for AWS services
```

### HTTP/1.1 vs HTTP/2 vs HTTP/3

```
HTTP/1.1 (1997):
  One request per TCP connection (sequential)
  Workaround: open multiple TCP connections (6 per browser)
  Head-of-line blocking: slow request blocks all others
  Text-based headers (verbose)

HTTP/2 (2015):
  Multiplexing: multiple requests over one TCP connection (parallel)
  Header compression (HPACK) — reduces overhead
  Server push: server proactively sends resources
  Binary protocol (more efficient than text)
  Still TCP-based → still has TCP head-of-line blocking
  
HTTP/3 (2022):
  Based on QUIC (UDP-based) instead of TCP
  Eliminates TCP head-of-line blocking
  Faster connection setup (0-RTT)
  Better performance on lossy/mobile networks
  QUIC built-in encryption (always TLS 1.3)

DevOps relevance:
  ALB supports HTTP/2 to clients
  CloudFront supports HTTP/3
  gRPC requires HTTP/2
```

---

## PART 5 — LOAD BALANCING

### L4 vs L7 Load Balancing

```
Layer 4 (Transport) Load Balancer:
  Sees: IP addresses, TCP/UDP ports, protocol
  Routes based on: IP + port
  Does NOT look inside the packet (no HTTP awareness)
  Very fast (minimal processing)
  
  Example: NLB (AWS Network Load Balancer)
  Use for:
    Non-HTTP traffic (game servers, MQTT, databases)
    Ultra-high performance (millions of req/sec)
    Static IP requirement (NLB gives static Elastic IPs)
    TCP passthrough (L7 LBs terminate TCP)

Layer 7 (Application) Load Balancer:
  Sees: HTTP headers, path, hostname, cookies, body
  Routes based on: URL path, hostname, HTTP headers, method
  Terminates TCP/TLS (decrypts, processes, re-encrypts)
  Slower than L4 but much more intelligent
  
  Example: ALB (AWS Application Load Balancer)
  Use for:
    HTTP/HTTPS traffic
    Path-based routing: /api → API servers, /static → CDN
    Host-based routing: api.domain.com → API, web.domain.com → web
    Header-based routing: canary via X-Canary: true header
    WebSocket, gRPC (HTTP/2)
    WAF integration (only ALB, not NLB)
    Authentication (Cognito, OIDC integration)

Real comparison:
  ALB: intelligent routing, cheaper, L7 features
  NLB: raw performance, static IP, any TCP/UDP protocol
  
  Your resume: ALB for judicial API → correct choice (HTTP API)
```

### Load Balancing Algorithms

```
Round Robin:
  Requests distributed evenly in sequence: 1→2→3→1→2→3
  Simple, effective when all servers have equal capacity
  Problem: ignores server load (busy server gets same traffic as idle)

Least Connections:
  New request goes to server with fewest active connections
  Better for long-lived connections (WebSocket, file uploads)
  Adapts to actual server load

IP Hash (Sticky/Session-based):
  Hash of client IP → always same server
  Same client always goes to same server
  Use for: stateful apps that store session on server
  Problem: if server dies → sessions lost, uneven distribution

Weighted Round Robin:
  Server A: weight 3, Server B: weight 1 → 75% to A, 25% to B
  Use when: servers have different capacity

Random:
  Random server selection
  Statistically converges to round-robin at scale

Least Response Time:
  Route to server with lowest latency + fewest connections
  Most sophisticated, best user experience
  Nginx Plus, HAProxy support this

AWS ALB uses: least outstanding requests (similar to least connections)
```

### Health Checks

```
Health checks prevent routing to broken instances:
  LB periodically pings target
  Failed checks → remove from rotation
  Recovered → add back automatically

AWS ALB health check settings:
  Protocol:           HTTP, HTTPS
  Path:               /health (your endpoint)
  Port:               traffic port or override
  Healthy threshold:  2 consecutive successes → mark healthy
  Unhealthy threshold:3 consecutive failures → mark unhealthy
  Interval:           30 seconds between checks
  Timeout:            5 seconds to respond

What your /health endpoint should return:
  HTTP 200: all dependencies OK
  HTTP 503: degraded (remove from rotation)
  Check: DB connectivity, external APIs, disk space

Layered health checks:
  Shallow:  just HTTP 200 from the app (is it running?)
  Deep:     checks DB connection, cache, critical dependencies
            Risk: shared dependency failing → all instances unhealthy → outage
  
  Best practice:
    ALB health check: shallow (is app running?)
    Separate monitoring: deep (is system healthy?)
    Don't cascade: don't take instance out of rotation for 3rd party failures
```

### Sticky Sessions

```
Problem: user session stored in memory on server A
         Next request goes to server B → session lost → user logged out

Solution 1: Sticky sessions (session affinity)
  LB adds cookie: AWSALB=<hash>
  All requests with same cookie → same server
  
  AWS ALB: enable target group stickiness
  Duration: 1 second to 7 days
  
  Problem:
    Server dies → sticky cookie useless → session lost anyway
    Uneven distribution if some users are "stickier"

Solution 2: Externalize sessions (better)
  Store sessions in Redis/ElastiCache (not on server)
  Any server can handle any request
  No sticky sessions needed
  Servers are truly stateless
  
  This is what you should design for in interviews:
  "I'd store sessions in ElastiCache Redis so any instance can handle any request"
```

---

## PART 6 — TCP vs UDP

### TCP (Transmission Control Protocol)

```
Reliable, ordered, error-checked delivery
  Connection-oriented: must establish connection before data
  
3-Way Handshake (connection setup):
  Client → Server: SYN (synchronize, I want to connect, here's my ISN)
  Server → Client: SYN-ACK (I got your SYN, here's my ISN, I'm ready)
  Client → Server: ACK (I got your SYN-ACK, connection established)
  
  ISN = Initial Sequence Number (random, to prevent attacks)
  
Data transfer:
  Each segment has sequence number
  Receiver sends ACK for each segment (or cumulative)
  Sender retransmits if no ACK received within timeout
  Out-of-order segments reassembled in correct order

Connection teardown (4-way handshake):
  Either side: FIN (I'm done sending)
  Other side: ACK (got it)
  Other side: FIN (I'm done too)
  First side: ACK (got it, connection closed)
  
  TIME_WAIT: initiator waits 2*MSL before fully closing
             Ensures all packets have left the network
             Causes "port already in use" errors if restarting server quickly

Flow control:
  Receiver advertises window size (how much data it can accept)
  Sender respects window: don't send more than receiver can handle

Congestion control:
  Slow start: start slow, increase rate exponentially until loss
  Congestion avoidance: reduce rate when packet loss detected
  
TCP use cases:
  HTTP/HTTPS, SSH, FTP, SMTP, database connections
  Any application where data integrity matters more than speed
```

### UDP (User Datagram Protocol)

```
Fast, connectionless, no guarantee of delivery
  No handshake: just send datagrams immediately
  No ordering: packets may arrive out of order
  No reliability: packets may be lost
  No flow control: receiver may be overwhelmed

UDP advantages:
  Very fast (no handshake overhead)
  Low latency (no retransmit delay)
  Application can implement its own reliability if needed
  
UDP use cases:
  DNS: single query/response, speed matters, app retries if needed
  Video streaming: old frames useless anyway, prefer speed
  Online gaming: real-time state, old updates irrelevant
  VoIP/WebRTC: real-time audio, gaps better than delays
  DHCP: broadcasts before having an IP
  SNMP: monitoring (ok to lose some packets)
  QUIC (HTTP/3): UDP with application-level reliability

Interview question:
  "Can you have reliable communication over UDP?"
  Yes — QUIC does this:
    Adds sequence numbers, acknowledgments at application layer
    Handles retransmission
    But avoids TCP's head-of-line blocking
    Each QUIC stream is independent (one packet loss doesn't block others)
```

### TCP Connection States

```
State           Description
─────────────────────────────────
CLOSED          No connection
LISTEN          Server waiting for connections
SYN_SENT        Client sent SYN, waiting for SYN-ACK
SYN_RECEIVED    Server received SYN, sent SYN-ACK
ESTABLISHED     Connection active, data transfer
FIN_WAIT_1      Sent FIN, waiting for ACK
FIN_WAIT_2      Got ACK for FIN, waiting for FIN from other side
CLOSE_WAIT      Got FIN from other side, waiting for local FIN
CLOSING         Both sides sent FIN simultaneously
LAST_ACK        Sent FIN, waiting for final ACK
TIME_WAIT       Waiting 2*MSL before fully closing

netstat -an | grep ESTABLISHED   # active connections
netstat -an | grep TIME_WAIT     # recently closed
netstat -an | grep LISTEN        # ports server is listening on
ss -tulnp                        # better than netstat on modern Linux
```

---

## PART 7 — FIREWALLS, PROXIES, REVERSE PROXIES

### Firewall Types

```
Packet Filter (stateless):
  Examines each packet independently
  Rules: source IP, destination IP, port, protocol
  Fast but limited — can't understand context
  Example: AWS NACLs
  
Stateful Firewall:
  Tracks connection state (NEW, ESTABLISHED, RELATED)
  Automatically allows return traffic for established connections
  More intelligent than packet filter
  Example: AWS Security Groups, iptables
  
Application Firewall (L7):
  Understands application protocols (HTTP, DNS, SMTP)
  Can inspect payload (not just headers)
  WAF (Web Application Firewall) is this type
  Example: AWS WAF, Cloudflare, ModSecurity

iptables (Linux firewall):
  CHAINS: INPUT (incoming), OUTPUT (outgoing), FORWARD (routing)
  
  # Allow established connections
  iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
  
  # Allow SSH
  iptables -A INPUT -p tcp --dport 22 -j ACCEPT
  
  # Allow HTTP/HTTPS
  iptables -A INPUT -p tcp --dport 80 -j ACCEPT
  iptables -A INPUT -p tcp --dport 443 -j ACCEPT
  
  # Block all other inbound
  iptables -A INPUT -j DROP
```

### Forward Proxy vs Reverse Proxy

```
Forward Proxy:
  Sits between CLIENTS and the internet
  Clients know they're using a proxy
  Internet doesn't see client IPs (sees proxy IP)
  
  Client → Forward Proxy → Internet
  
  Use cases:
    Corporate internet filtering (block social media)
    Anonymization / privacy
    Bypass geo-restrictions
    Caching for corporate users
    Access logging/monitoring
  
  Client must be configured to use proxy:
    export HTTP_PROXY=http://proxy.company.com:3128
    export HTTPS_PROXY=http://proxy.company.com:3128
    export NO_PROXY=localhost,10.0.0.0/8

Reverse Proxy:
  Sits in front of SERVERS
  Clients don't know it exists (appears as the server)
  Servers don't see client IPs directly (see proxy IP)
  
  Client → Internet → Reverse Proxy → Backend Servers
  
  Use cases:
    Load balancing (distribute across multiple servers)
    SSL termination (decrypt HTTPS, forward HTTP to backends)
    Caching (serve cached responses)
    Compression (gzip responses)
    Authentication (validate tokens before reaching backend)
    API gateway
    DDoS protection (hide backend IPs)
  
  Examples: Nginx, HAProxy, Traefik, AWS ALB, CloudFront

  X-Forwarded-For header:
    Reverse proxy adds original client IP to this header
    Backend can read: request.headers['X-Forwarded-For']
    Without this: backend only sees proxy IP (loses client IP)
```

### Nginx as Reverse Proxy

```nginx
# nginx.conf — reverse proxy with SSL termination

events { worker_connections 1024; }

http {
    # Upstream (backend servers)
    upstream judicial_api {
        least_conn;  # load balancing algorithm
        server 10.0.2.10:8080 weight=3;
        server 10.0.2.11:8080 weight=1;
        keepalive 32;  # keep connections to backends alive
    }

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=100r/m;

    # HTTP → HTTPS redirect
    server {
        listen 80;
        server_name judicialsolutions.in;
        return 301 https://$host$request_uri;
    }

    # HTTPS server
    server {
        listen 443 ssl http2;
        server_name judicialsolutions.in;

        # SSL config
        ssl_certificate     /etc/ssl/certs/judicial.crt;
        ssl_certificate_key /etc/ssl/private/judicial.key;
        ssl_protocols       TLSv1.2 TLSv1.3;
        ssl_ciphers         HIGH:!aNULL:!MD5;

        # Security headers
        add_header Strict-Transport-Security "max-age=31536000" always;
        add_header X-Frame-Options DENY always;
        add_header X-Content-Type-Options nosniff always;

        # Proxy to backend
        location /api/ {
            limit_req zone=api_limit burst=20 nodelay;
            
            proxy_pass http://judicial_api;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            proxy_connect_timeout 5s;
            proxy_read_timeout 30s;
        }

        # Static files (serve directly, skip backend)
        location /static/ {
            alias /var/www/static/;
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
}
```

---

## PART 8 — CDN FUNDAMENTALS

### How CDNs Work

```
Without CDN:
  User in Mumbai → requests image → travels to us-east-1 server
  Round trip: ~200ms (speed of light + routing)
  
With CDN:
  User in Mumbai → requests image → nearest edge server (Mumbai PoP)
  If cached: served in ~10ms (same city)
  If not cached: edge fetches from origin, caches, serves to user
  
CDN = network of edge servers globally distributed
  CloudFront: 450+ edge locations worldwide
  Cloudflare: 285+ locations
  Fastly, Akamai: alternatives

What gets cached:
  Static assets: CSS, JS, images, fonts, videos (long TTL)
  API responses: if Cache-Control allows (short TTL)
  Anything that doesn't need to be real-time per user
  
What doesn't get cached:
  User-specific data (different per user)
  Responses with Set-Cookie header
  POST/PUT/DELETE requests (only GET/HEAD by default)
  No-store responses
```

### CloudFront Deep Dive

```
Origins:
  S3 bucket (static website)
  ALB (dynamic application)
  API Gateway
  Custom HTTP server
  Multiple origins (origin groups for failover)

Behaviors:
  Pattern matching on URL path → different origin + cache settings
  /api/*  → no cache, forward to ALB
  /static/* → cache 1 year, from S3
  /images/* → cache 7 days, from S3

Cache key:
  What makes a "unique" cached response?
  Default: URL only
  Custom: URL + specific headers + query params + cookies
  More cache key components → more cache entries → lower hit rate

Cache-Control headers:
  no-store:         CloudFront doesn't cache at all
  no-cache:         CloudFront caches but validates with origin each time
  max-age=3600:     cache for 1 hour
  s-maxage=3600:    cache for 1 hour (for CDNs specifically, overrides max-age)
  public:           OK to cache in shared cache (CDN)
  private:          only browser caches (not CDN)

CloudFront TTL hierarchy:
  Minimum TTL: 0 (default)
  Maximum TTL: 31,536,000 (1 year)
  Default TTL: 86,400 (1 day)
  Origin header overrides these if within min/max range

OAC (Origin Access Control):
  CloudFront authenticates to S3 with SigV4
  S3 bucket can be private (no public access)
  Only CloudFront can access it (not direct S3 URLs)
  
Cache invalidation:
  When you deploy new static assets → CDN has old versions
  Invalidate: aws cloudfront create-invalidation --paths "/*"
  Cost: $0.005 per 1,000 paths (first 1,000/month free)
  Better approach: versioned filenames (app.abc123.js)
                   filename changes on deploy → no invalidation needed
```

```bash
# CloudFront CLI
# Create invalidation
aws cloudfront create-invalidation \
  --distribution-id E1234ABCDEF \
  --paths "/*"

# Invalidate specific paths
aws cloudfront create-invalidation \
  --distribution-id E1234ABCDEF \
  --paths "/index.html" "/app.js" "/styles.css"

# Check invalidation status
aws cloudfront get-invalidation \
  --distribution-id E1234ABCDEF \
  --id INVALIDATION_ID

# Get distribution config
aws cloudfront get-distribution-config \
  --id E1234ABCDEF
```

---

## PART 9 — NETWORK TROUBLESHOOTING

### The Troubleshooting Toolkit

```bash
# ─── CONNECTIVITY ─────────────────────────────────────────────

# Basic ping (ICMP) — is host reachable?
ping google.com          # continuous ping
ping -c 4 google.com     # send 4 packets
ping -i 0.5 google.com   # 0.5s interval

# Note: some hosts block ICMP → ping fails but TCP works
# If ping fails but curl works → ICMP blocked (not a real problem)

# Traceroute — trace path to destination
traceroute google.com    # Linux (UDP-based)
tracert google.com       # Windows (ICMP-based)
mtr google.com           # continuous traceroute (best tool for network issues)
  # Shows: each hop, latency, packet loss per hop
  # High loss at one hop but not next → that router deprioritizes ICMP

# Test TCP connectivity (is port open?)
nc -zv google.com 443       # netcat: test if port 443 is open
nc -zvw 5 10.0.0.5 5432     # test postgres port, 5s timeout
telnet 10.0.0.5 5432         # older alternative to nc
curl -v --connect-timeout 5 http://service:8080/health  # test HTTP

# ─── DNS ──────────────────────────────────────────────────────

dig judicialsolutions.in
dig +trace judicialsolutions.in    # full resolution chain
dig @8.8.8.8 judicialsolutions.in  # use specific DNS server
nslookup judicialsolutions.in
host judicialsolutions.in          # simple lookup

# Check DNS inside container/pod
kubectl exec my-pod -- nslookup kubernetes.default
kubectl exec my-pod -- cat /etc/resolv.conf  # DNS config

# ─── HTTP ─────────────────────────────────────────────────────

# curl — the most powerful HTTP debugging tool
curl -v https://api.judicialsolutions.in/health    # verbose (shows headers)
curl -I https://api.judicialsolutions.in           # HEAD request (headers only)
curl -X POST https://api/cases \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN" \
  -d '{"title":"Test case"}' \
  -v

# Measure HTTP timing (latency breakdown)
curl -w "\n
DNS lookup:        %{time_namelookup}s
TCP connect:       %{time_connect}s
TLS handshake:     %{time_appconnect}s
Time to first byte:%{time_starttransfer}s
Total time:        %{time_total}s
\n" -o /dev/null -s https://api.judicialsolutions.in

# Follow redirects
curl -L http://judicialsolutions.in    # -L follows redirects

# Check certificate
curl -v --insecure https://api.example.com  # ignore cert errors
openssl s_client -connect judicialsolutions.in:443 -servername judicialsolutions.in

# Check certificate expiry
echo | openssl s_client -connect judicialsolutions.in:443 2>/dev/null \
  | openssl x509 -noout -dates

# ─── PORTS AND CONNECTIONS ────────────────────────────────────

# What's listening on which port?
ss -tulnp                # modern (preferred over netstat)
netstat -tulnp           # older systems
lsof -i :8080            # what process is using port 8080?
lsof -i tcp              # all TCP connections

# Active connections
ss -s                    # summary of connections
ss -an | grep ESTABLISHED
ss -an | grep TIME_WAIT  # connections waiting to close

# ─── PACKET CAPTURE ────────────────────────────────────────────

# tcpdump — capture network packets
tcpdump -i eth0                        # all traffic on eth0
tcpdump -i eth0 port 443               # only HTTPS traffic
tcpdump -i eth0 host 10.0.0.5         # traffic to/from specific host
tcpdump -i eth0 port 5432 -w db.pcap  # save to file

# View captured file in Wireshark (on your laptop)
# Or: tcpdump -r db.pcap

# ─── ROUTES AND INTERFACES ─────────────────────────────────────

# Show network interfaces
ip addr show            # all interfaces with IPs
ip link show            # all interfaces

# Show routing table
ip route show
route -n

# Show ARP cache (L2 → L3 mapping)
arp -a
ip neigh show

# Add static route
ip route add 10.1.0.0/16 via 10.0.0.1
```

### Reading tcpdump Output

```bash
# Example tcpdump output:
# 14:30:01.123456 IP 10.0.1.5.54321 > 10.0.2.100.5432: Flags [S], seq 123456
#                    SOURCE IP.PORT  > DEST IP.PORT     FLAGS

# TCP Flags:
# [S]   = SYN (connection initiation)
# [S.]  = SYN-ACK (server response)
# [.]   = ACK (acknowledgement)
# [P.]  = PSH-ACK (data with push)
# [F.]  = FIN-ACK (connection close)
# [R]   = RST (reset — immediate close, often means connection refused)

# Connection refused: RST immediately after SYN
# 14:30:01 IP client.12345 > server.5432: Flags [S]     ← client tries
# 14:30:01 IP server.5432  > client.12345: Flags [R.]   ← server refuses (port closed/no listener)

# Connection timeout: no response to SYN
# 14:30:01 IP client.12345 > server.5432: Flags [S]     ← SYN
# (silence)
# 14:30:04 IP client.12345 > server.5432: Flags [S]     ← retransmit
# (more silence)
# → firewall is dropping packets (not rejecting — just dropping)
```

---

## PART 10 — COMMON DEVOPS NETWORKING SCENARIOS

### Scenario 1: "My container can't reach the database"

```
Error: "Connection refused" or "No route to host" or timeout

Systematic diagnosis:

Step 1: Is the DB actually running and listening?
  kubectl exec db-pod -- netstat -tulnp | grep 5432
  docker exec db-container ss -tulnp | grep 5432
  # Should show: tcp LISTEN 0 128 0.0.0.0:5432

Step 2: Can you reach the DB from inside the container?
  kubectl exec app-pod -- nc -zv db-service 5432
  kubectl exec app-pod -- nslookup db-service
  
  If DNS fails: DNS issue
  If DNS works but nc fails: network/firewall issue

Step 3: Check service/endpoint (Kubernetes)
  kubectl get service db-service
  kubectl get endpoints db-service
  # If endpoints is <none>: pod selector doesn't match DB pod labels

Step 4: Check NetworkPolicy (Kubernetes)
  kubectl get networkpolicy -n production
  # Is there a policy blocking the connection?

Step 5: Check security groups (AWS)
  AWS Console → EC2 → Security Groups
  DB security group: does it allow port 5432 from app security group?

Step 6: Check app is using correct address
  kubectl exec app-pod -- env | grep DB
  # Is DB_HOST pointing to correct service name / DNS name?
  
  Common mistake:
    DB_HOST=localhost → wrong (that's the app container itself)
    DB_HOST=postgres  → correct (K8s service name or Docker Compose name)

Connection refused vs timeout:
  "Connection refused" (RST): port is closed, nothing listening
  Timeout (no response):      firewall dropping packets
```

### Scenario 2: "Why is my API slow? Users complaining about latency"

```
Diagnose where the time is being spent:

Step 1: Measure end-to-end latency breakdown
  curl -w "DNS:%{time_namelookup} TCP:%{time_connect} TLS:%{time_appconnect} TTFB:%{time_starttransfer} Total:%{time_total}" \
    -o /dev/null -s https://api.judicialsolutions.in/cases

  DNS time high → DNS server slow, TTL too low
  TCP connect high → geographic distance, packet loss
  TLS time high → certificate chain too long, no session resumption
  TTFB high → server processing slow (backend issue)

Step 2: Check if it's DNS
  time dig api.judicialsolutions.in
  # > 100ms → slow DNS
  # Fix: use Route53 (fast), add TTL, enable DNS caching

Step 3: Check server-side
  kubectl top pods  # is a pod using excessive CPU?
  kubectl logs -l app=api --tail=100 | grep "slow"
  # Check CloudWatch: Lambda Duration p99

Step 4: Check geographic latency
  Is user far from your region?
  Fix: CloudFront → serve from nearest edge
  → static assets served in <20ms regardless of user location

Step 5: Network path issues
  mtr api.judicialsolutions.in
  # Shows each hop with latency and packet loss
  # Sudden jump at a hop → congestion at that router
```

### Scenario 3: "HTTPS is working but certificate shows as invalid"

```
Possible causes and how to check:

1. Certificate expired
  openssl s_client -connect example.com:443 2>/dev/null | \
    openssl x509 -noout -dates
  # NotAfter: Jan 01 00:00:00 2024 GMT ← expired

  Fix: cert-manager (auto-renew) or rotate manually
  Prevention: Alert on expiry < 30 days (Prometheus/CloudWatch)

2. Wrong certificate (different domain)
  openssl s_client -connect api.example.com:443 2>/dev/null | \
    openssl x509 -noout -subject
  # subject=CN = other.example.com ← wrong cert

  Fix: serve correct certificate for this virtual host

3. Self-signed certificate (not trusted by browser)
  openssl s_client -connect example.com:443 2>/dev/null
  # "Verify return code: 18 (self signed certificate)"
  
  Fix: use Let's Encrypt or ACM (free, trusted CAs)

4. Certificate chain incomplete
  Browser builds chain: leaf cert → intermediate CAs → root CA
  If intermediate CA cert missing → chain broken → invalid
  Fix: include full chain (cert + intermediate) in server config
  
  Check: ssl.labs/ssltest → shows chain completeness

5. SNI (Server Name Indication) issue
  Multiple domains on same IP, wrong cert served
  Fix: ensure TLS config uses SNI-based virtual hosting
  curl -v --resolve api.example.com:443:IP_ADDRESS https://api.example.com
```

### Scenario 4: "Pod can reach internet but can't reach other pods in different namespace"

```
Kubernetes networking:
  By default: all pods can reach all other pods (no isolation)
  If NetworkPolicy exists: traffic blocked unless explicitly allowed

Step 1: Test connectivity
  kubectl exec frontend-pod -n frontend -- \
    nc -zv backend-svc.backend.svc.cluster.local 8080

Step 2: Check DNS resolution
  kubectl exec frontend-pod -n frontend -- \
    nslookup backend-svc.backend.svc.cluster.local
  
  # FQDN format: service.namespace.svc.cluster.local
  # Short form only works within same namespace

Step 3: Check NetworkPolicy
  kubectl get networkpolicy -n backend
  kubectl describe networkpolicy -n backend
  
  If NetworkPolicy exists: check if it allows from frontend namespace
  
  # Fix: add ingress rule allowing from frontend namespace
  spec:
    podSelector:
      matchLabels:
        app: backend
    ingress:
    - from:
      - namespaceSelector:
          matchLabels:
            name: frontend
      ports:
      - port: 8080

Step 4: Check Service exists and has endpoints
  kubectl get service backend-svc -n backend
  kubectl get endpoints backend-svc -n backend
  # Endpoints <none> → selector not matching pods
```

### Scenario 5: "Load balancer returns 502"

```
502 Bad Gateway = LB got invalid response from backend
                = LB can't reach backend at all

Diagnosis:

Step 1: Check target health in AWS
  aws elbv2 describe-target-health \
    --target-group-arn arn:aws:elasticloadbalancing:...
  # "State": "unhealthy" → backend failing health check

Step 2: Check why backend is unhealthy
  # Health check path: is /health returning 200?
  # From inside the backend EC2/container:
  curl http://localhost:8080/health
  
  If app is down: check logs, restart
  If app returns non-200: fix health endpoint

Step 3: Security group issue
  ALB SG: allows outbound to backend port?
  Backend SG: allows inbound from ALB SG?
  
  # Check ALB outbound rules (should allow 8080 to backend SG)
  # Check Backend inbound rules (should allow 8080 from ALB SG)

Step 4: Check backend is listening on correct interface
  ss -tulnp | grep 8080
  # App listening on 127.0.0.1:8080 → ALB can't reach it
  # App must listen on 0.0.0.0:8080

Step 5: Protocol mismatch
  ALB configured as HTTPS but backend responds HTTP (or vice versa)
  Fix: match ALB listener protocol with backend protocol

Common fixes:
  ALB 502 → backend app crashed → restart, check logs
  ALB 502 → health check failing → fix /health endpoint
  ALB 502 → backend not listening on 0.0.0.0 → fix app binding
  ALB 503 → no healthy targets → scale up, check health checks
  ALB 504 → backend too slow → increase timeout or fix slow queries
```

---

## INTERVIEW QUESTIONS RAPID FIRE

**Q: What happens between typing a URL and seeing the webpage?**
```
DNS: resolve domain → IP (browser cache → OS cache → recursive → root → TLD → authoritative)
TCP: 3-way handshake (SYN → SYN-ACK → ACK)
TLS: certificate exchange, key negotiation, session established
HTTP: GET request with headers
Server: processes request, generates response
HTTP response: status code + headers + body
Browser: renders HTML, fetches CSS/JS/images (additional requests)
```

**Q: What's the difference between L4 and L7 load balancers?**
```
L4 (Transport): routes by IP + port, doesn't inspect packet content
  Fast, handles any TCP/UDP protocol
  AWS NLB, static IP, for non-HTTP workloads

L7 (Application): routes by HTTP headers, path, hostname, cookies
  Intelligent routing, SSL termination, WAF integration
  AWS ALB, for HTTP/HTTPS workloads

Your resume: ALB for judicial API → correct (HTTP API + path routing)
```

**Q: How does DNS caching work and how does it affect deployments?**
```
DNS responses are cached at: browser, OS, recursive resolver
Cached for: TTL (Time To Live) seconds specified in the record

On deployment (IP change):
  If old TTL = 86400 (1 day): cached clients hit old IP for up to 24hrs
  
Migration strategy:
  1. Lower TTL to 60s, 48 hours BEFORE migration
  2. Wait for old TTL to expire everywhere
  3. Change DNS record (propagates in 60 seconds)
  4. Raise TTL back after migration

This is why "DNS propagation takes 24 hours" — it's TTL, not propagation
```

**Q: What's the difference between a forward proxy and reverse proxy?**
```
Forward proxy: sits in front of CLIENTS → clients use it to access internet
  Clients know about it, configure explicitly
  Use: corporate filtering, anonymization, caching
  Example: Squid proxy

Reverse proxy: sits in front of SERVERS → clients think it's the server
  Clients don't know it exists
  Use: load balancing, SSL termination, caching, DDoS protection
  Example: Nginx, AWS ALB, CloudFront

In DevOps: we mostly work with reverse proxies
  Nginx in front of your app = reverse proxy
  CloudFront in front of S3/ALB = reverse proxy
```

---

## QUICK REFERENCE

### Ports to Remember
```
20/21  FTP (data/control)        443   HTTPS
22     SSH                        3306  MySQL
23     Telnet (insecure)          5432  PostgreSQL
25     SMTP (email)               6379  Redis
53     DNS                        27017 MongoDB
80     HTTP                       2379  etcd
123    NTP (time sync)            6443  Kubernetes API
143    IMAP (email)               8080  Common HTTP alt
389    LDAP                       8443  Common HTTPS alt
443    HTTPS                      9090  Prometheus
445    SMB (Windows shares)       9200  Elasticsearch
3000   Grafana                    9100  Node Exporter
```

### Network Troubleshooting Cheat Sheet
```
Can't ping host:      ICMP blocked (check firewall) — try nc/curl instead
nc -zv fails:         port closed OR firewall blocking TCP
curl times out:       firewall dropping (no RST) — check SG/NACL/NetworkPolicy
curl refused:         app not running or not listening on that port/interface
502 from LB:          backend unhealthy or LB can't reach it
503 from LB:          no healthy targets in target group
504 from LB:          backend too slow (increase timeout or fix app)
DNS fails in pod:     check /etc/resolv.conf, check CoreDNS pods running
ping works, curl fails: app issue (DNS → IP works, but app layer broken)
Same-AZ works, cross-AZ fails: security group issue (SG rule by SG id, not CIDR)
```

### OSI Model One-Liner per Layer
```
L7 Application:  HTTP, DNS, SMTP — YOUR APPLICATION
L6 Presentation: TLS encryption, data encoding
L5 Session:      Session management (mostly merged with L7)
L4 Transport:    TCP/UDP — PORTS, reliability
L3 Network:      IP — ROUTING between networks
L2 Data Link:    Ethernet/WiFi — MAC addresses, same network
L1 Physical:     Cables, radio waves, electrical signals
```
