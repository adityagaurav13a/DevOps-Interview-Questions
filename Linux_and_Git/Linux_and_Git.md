# Linux + Git Complete Deep Dive
## Processes + Filesystem + Networking + Shell Scripting + Git
### Theory → Commands → Real DevOps Scenarios → Interview Questions

---

## README

**Total sections:** 16 (8 Linux + 8 Git)
**Target:** Mid-level to Senior DevOps/Cloud Engineer interviews
**Approach:** Theory first, then hands-on commands, then interview scenarios

### Power phrases:
- *"zombie process has finished but parent hasn't called wait() — it stays in process table"*
- *"inode is metadata — filename is just a pointer to an inode"*
- *"rebase rewrites history — use for local cleanup, never on shared branches"*
- *"git reflog is your safety net — nothing is truly lost for 90 days"*

---

## 📌 TABLE OF CONTENTS

### LINUX
| # | Section | Key Topics |
|---|---|---|
| L1 | [Processes](#l1--processes) | ps, top, signals, zombie, orphan, fork |
| L2 | [Filesystem](#l2--filesystem) | inodes, permissions, links, find, df, du |
| L3 | [Users and Permissions](#l3--users-and-permissions) | chmod, chown, sudo, sudoers, umask |
| L4 | [Networking](#l4--linux-networking) | netstat, ss, iptables, curl, tcpdump, nc |
| L5 | [systemd and Services](#l5--systemd-and-services) | unit files, journalctl, service management |
| L6 | [Shell Scripting](#l6--shell-scripting) | bash, loops, functions, traps, cron |
| L7 | [Performance and Debugging](#l7--performance-and-debugging) | top, vmstat, iostat, strace, lsof |
| L8 | [Linux Interview Scenarios](#l8--linux-interview-scenarios) | Real DevOps troubleshooting Q&As |

### GIT
| # | Section | Key Topics |
|---|---|---|
| G1 | [Git Internals](#g1--git-internals) | objects, blobs, trees, commits, refs |
| G2 | [Branching Strategies](#g2--branching-strategies) | GitFlow, trunk-based, when to use each |
| G3 | [Merge vs Rebase](#g3--merge-vs-rebase) | when to use which, interactive rebase |
| G4 | [Undoing Things](#g4--undoing-things) | reset, revert, restore, reflog |
| G5 | [Advanced Git](#g5--advanced-git) | cherry-pick, stash, bisect, hooks |
| G6 | [Git in CI/CD](#g6--git-in-cicd) | tagging, signing, protected branches |
| G7 | [GitOps](#g7--gitops) | ArgoCD pattern, git as source of truth |
| G8 | [Git Interview Questions](#g8--git-interview-questions) | 15 Q&As — basic to senior |

---

# ══════════════════════════════════════
# LINUX
# ══════════════════════════════════════

## L1 — PROCESSES

### What is a Process?

```
Process = running instance of a program
  Has: PID (unique ID), memory space, open files, CPU time
  Parent: every process has a parent (except PID 1)
  
Process hierarchy:
  PID 1 (init/systemd) — the first process
    → sshd (listens for SSH)
      → bash (your shell)
        → python app.py (your app)
          → child threads

Every process has:
  PID:   unique process ID
  PPID:  parent PID
  UID:   which user owns it
  State: Running, Sleeping, Stopped, Zombie
```

### ps — Process Snapshot

```bash
# Show all processes (most common)
ps aux
# a = all users, u = user-oriented format, x = include non-tty

# Output columns:
# USER  PID  %CPU  %MEM  VSZ    RSS   TTY  STAT  START  TIME  COMMAND
# root  1234  2.3   1.1   987M  45M   ?    Ss    10:30  0:02  python app.py

# STAT codes:
# R = Running
# S = Sleeping (interruptible)
# D = Sleeping (uninterruptible — usually I/O wait)
# Z = Zombie (finished but not reaped)
# T = Stopped
# s = session leader
# l = multi-threaded

# Find specific process
ps aux | grep nginx
ps aux | grep python | grep -v grep

# Process tree (shows parent-child)
ps axjf
pstree -p          # visual tree with PIDs

# Sort by CPU usage
ps aux --sort=-%cpu | head -10

# Sort by memory
ps aux --sort=-%mem | head -10

# Show specific columns
ps -eo pid,ppid,user,stat,command --sort=%cpu | head -20
```

### top and htop

```bash
# top — real-time process monitor
top

# Inside top:
# q       = quit
# k       = kill process (enter PID)
# r       = renice (change priority)
# 1       = show per-CPU stats
# M       = sort by memory
# P       = sort by CPU
# f       = add/remove columns
# u       = filter by user

# Understanding top header:
# load average: 0.5, 1.2, 0.8
#               ^1min ^5min ^15min
# Load > number of CPUs = system is overloaded
# 2 CPUs + load 4.0 = 2x overloaded

# htop — better interactive version
htop
# Colour-coded bars, mouse support, easier to use
# F5 = tree view, F6 = sort, F9 = kill

# One-liner: top CPU consumers
top -bn1 | grep -A 15 "PID USER" | head -15
```

### Signals — Communicating with Processes

```bash
# List all signals
kill -l

# Most important signals:
# SIGTERM (15) — graceful shutdown request
#                process can catch this, clean up, then exit
#                THIS is what K8s sends during pod termination
#                THIS is what systemctl stop sends
#
# SIGKILL (9)  — force kill, cannot be caught or ignored
#                OS kills process immediately, no cleanup
#                Last resort — may leave tmp files, corrupt data
#
# SIGHUP  (1)  — hangup — reload config (nginx, sshd use this)
#                nginx: kill -HUP $(cat /run/nginx.pid)
#
# SIGINT  (2)  — keyboard interrupt (Ctrl+C)
#
# SIGSTOP (19) — pause process (Ctrl+Z)
# SIGCONT (18) — resume paused process

# Send signals
kill 1234          # sends SIGTERM (default) to PID 1234
kill -15 1234      # explicit SIGTERM
kill -9 1234       # SIGKILL (force)
kill -HUP 1234     # reload config
killall nginx      # kill all processes named nginx
pkill -f "python app.py"  # kill by command pattern

# Send signal to process group
kill -9 -1234      # kill entire process group (negative PID)
```

### Process States — Zombie and Orphan

```
Zombie Process:
  Process has FINISHED executing
  But parent hasn't called wait() to collect exit status
  Process stays in process table as "Z" (zombie)
  Takes no CPU, takes no memory
  BUT takes a PID slot (finite resource)
  Too many zombies = can't create new processes

  How it happens:
    Parent spawns child
    Child finishes → becomes zombie (waiting for parent to read status)
    Parent is buggy → never reads child's exit status
    Zombie accumulates

  How to fix:
    Kill the PARENT (parent cleans up its zombies)
    Or: fix the parent to call wait()
    You CANNOT kill a zombie directly (it's already dead)

  Detect:
    ps aux | grep Z  ← look for Z in STAT column

Orphan Process:
  Parent died before child
  Child becomes orphan
  init/systemd (PID 1) ADOPTS the orphan automatically
  Not harmful — PID 1 reaps them properly

  Example:
    Shell script spawns background process
    Shell exits (parent dies)
    Background process becomes orphan → adopted by init
    Continues running fine

Fork bomb (understanding, not doing):
  :(){ :|:& };:    ← creates infinite child processes
  Fills up process table → system unusable
  Prevention: ulimit -u 1000 (max 1000 processes per user)
```

### Process Priority (nice/renice)

```bash
# Priority range: -20 (highest) to +19 (lowest)
# Default: 0
# Lower number = higher priority = more CPU time

# Start process with lower priority
nice -n 10 python heavy_script.py

# Change priority of running process
renice -n 5 -p 1234      # lower priority of PID 1234
renice -n -5 -p 1234     # increase priority (needs root)

# In K8s context:
# QoS class = Guaranteed → OS gives it priority
# QoS class = BestEffort → OS can deprioritize when busy
```

---

## L2 — FILESYSTEM

### Linux Filesystem Hierarchy

```
/           root — everything starts here
├── bin     essential user binaries (ls, cat, grep)
├── sbin    system binaries (mount, iptables, fdisk)
├── etc     configuration files (nginx.conf, ssh/sshd_config)
├── var     variable data (logs, databases, mail)
│   └── log → system logs
├── tmp     temporary files (deleted on reboot)
├── home    user home directories
├── root    root user's home
├── proc    virtual filesystem — kernel info as files
│   ├── /proc/1/      → info about PID 1
│   ├── /proc/cpuinfo → CPU info
│   └── /proc/meminfo → memory info
├── sys     virtual filesystem — hardware/kernel interfaces
├── dev     device files (disks, terminals, random)
│   ├── /dev/sda       → first disk
│   ├── /dev/null      → black hole (discard output)
│   ├── /dev/zero      → infinite zeros
│   └── /dev/random    → random data
├── mnt     temporary mount points
├── opt     optional/third-party software
├── usr     user programs and data
│   ├── bin → most user commands
│   └── lib → libraries
└── lib     essential libraries
```

### Inodes — What Every DevOps Engineer Should Know

```
inode = metadata about a file
  Contains: file size, permissions, timestamps, owner,
            block locations on disk
  Does NOT contain: filename

Filename → inode number → actual data blocks

Why this matters:
  Disk can be "full" even with free space if inodes exhausted
  Hard links: two filenames pointing to same inode
  Symlinks: file containing a path (pointer to another filename)

Check inodes:
  df -i           ← inode usage per filesystem
  ls -i file      ← show inode number
  stat file       ← full inode info

  stat /etc/nginx/nginx.conf
  # File: /etc/nginx/nginx.conf
  # Size: 1234      Blocks: 8   IO Block: 4096  regular file
  # Inode: 123456   Links: 1
  # Access: (0644/-rw-r--r--)  Uid: 0   Gid: 0
  # Access: 2024-03-22 10:30:00 ← atime (last read)
  # Modify: 2024-03-20 15:00:00 ← mtime (last content change)
  # Change: 2024-03-20 15:00:00 ← ctime (last metadata change)

Hard link:
  ln /etc/nginx/nginx.conf /tmp/nginx-backup.conf
  Both filenames → same inode → same data
  Delete one → other still works
  Delete both → inode freed → data deleted

Symbolic link (symlink):
  ln -s /etc/nginx/nginx.conf /tmp/nginx-link.conf
  /tmp/nginx-link.conf → "/etc/nginx/nginx.conf" (string)
  If original deleted → symlink is broken (dangling)
  Can span filesystems, can point to directories
```

### Essential File Commands

```bash
# Find files
find /var/log -name "*.log" -mtime -7        # logs modified in last 7 days
find /tmp -size +100M                         # files > 100MB
find / -user appuser -type f                  # files owned by appuser
find /etc -name "*.conf" -exec grep -l "nginx" {} \;  # conf files containing nginx

# Disk usage
df -h                  # disk space per filesystem
df -i                  # inode usage
du -sh /var/log        # total size of directory
du -sh /var/log/*      # size of each item in directory
du -sh * | sort -rh | head -10  # top 10 largest items

# Find what's using disk space
ncdu /var              # interactive disk usage (install if not present)

# Text processing
grep -r "ERROR" /var/log/nginx/          # recursive search
grep -v "GET /health" access.log         # exclude health checks
grep -c "ERROR" app.log                  # count occurrences
grep -n "CRITICAL" app.log               # show line numbers
grep -A 5 -B 5 "OOM" /var/log/syslog   # 5 lines around match

# awk — column processing
awk '{print $1, $7}' access.log          # print columns 1 and 7
awk -F: '{print $1}' /etc/passwd         # print usernames (: delimiter)
awk '$9 >= 500' access.log               # lines where 9th field >= 500
awk '{sum += $1} END {print sum}' nums   # sum first column

# sed — stream editor
sed 's/foo/bar/g' file.txt               # replace foo with bar
sed -i 's/old/new/g' file.txt           # edit file in place
sed '/^#/d' config.conf                  # delete comment lines
sed -n '10,20p' file.txt                # print lines 10-20

# sort, uniq, wc
sort -k2 -n file.txt                     # sort by 2nd column numerically
sort | uniq -c | sort -rn | head -10    # frequency count
wc -l file.txt                          # count lines
wc -w file.txt                          # count words
```

### Log Files — Where to Look

```bash
# System logs
/var/log/syslog          # general system log (Ubuntu/Debian)
/var/log/messages        # general system log (RHEL/CentOS)
/var/log/auth.log        # SSH logins, sudo commands
/var/log/kern.log        # kernel messages
/var/log/dmesg           # boot + hardware messages

# Application logs
/var/log/nginx/access.log
/var/log/nginx/error.log
/var/log/httpd/          # Apache
/var/log/postgresql/     # PostgreSQL

# Real-time log watching
tail -f /var/log/nginx/error.log          # follow live
tail -f /var/log/nginx/error.log | grep ERROR   # filter live
multitail /var/log/nginx/error.log /var/log/app.log  # multiple files

# journalctl (systemd)
journalctl -u nginx                       # nginx logs
journalctl -u nginx --since "1 hour ago"  # last hour
journalctl -f                            # follow all system logs
journalctl -p err                        # only errors
journalctl --disk-usage                  # how much space logs use
```

---

## L3 — USERS AND PERMISSIONS

### File Permissions

```
Permission string: -rwxr-xr--
                   ^ ^^^ ^^^ ^^^
                   | |   |   └── others (world): r--  = read only
                   | |   └────── group:          r-x  = read + execute
                   | └────────── owner:          rwx  = read + write + execute
                   └──────────── type: - file, d directory, l symlink

Permission bits:
  r = 4 (read)
  w = 2 (write)
  x = 1 (execute)

  rwx = 4+2+1 = 7
  r-x = 4+0+1 = 5
  r-- = 4+0+0 = 4
  --- = 0

  Common modes:
  644 = -rw-r--r--   (files: owner rw, group r, others r)
  755 = -rwxr-xr-x   (scripts/dirs: owner rwx, group rx, others rx)
  600 = -rw-------   (private files: owner rw only, like SSH keys)
  700 = -rwx------   (private scripts)
  777 = -rwxrwxrwx   (never in production!)

For directories:
  r = can list contents (ls)
  w = can create/delete files inside
  x = can cd into it, access files inside
```

```bash
# Change permissions
chmod 644 config.conf
chmod 755 deploy.sh
chmod -R 750 /app/scripts    # recursive
chmod u+x script.sh          # add execute for owner
chmod go-w sensitive.txt     # remove write for group and others

# Change ownership
chown appuser:appgroup /app/data
chown -R nginx:nginx /var/www/html
chown appuser file.txt       # change user only

# Check permissions
ls -la /etc/nginx/
stat /etc/nginx/nginx.conf

# Special permissions
# SUID (4000): run file as file's owner
chmod u+s /usr/bin/passwd
# SGID (2000): run file as file's group
chmod g+s /shared/dir
# Sticky bit (1000): only owner can delete files in directory
chmod +t /tmp   # ls shows: drwxrwxrwt
```

### sudo and sudoers

```bash
# Run as root
sudo command
sudo -i          # interactive root shell
sudo -u appuser command   # run as specific user

# Edit sudoers (ALWAYS use visudo — validates syntax)
sudo visudo

# sudoers examples:
# Allow user to run specific commands without password:
aditya ALL=(ALL) NOPASSWD: /bin/systemctl restart nginx
aditya ALL=(ALL) NOPASSWD: /usr/bin/docker

# Allow group devops to run all commands:
%devops ALL=(ALL) ALL

# Allow jenkins to run deploy script:
jenkins ALL=(ALL) NOPASSWD: /opt/scripts/deploy.sh

# Check what sudo access current user has
sudo -l

# /etc/sudoers.d/ — drop-in files (safer than editing sudoers directly)
echo "aditya ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/aditya
chmod 440 /etc/sudoers.d/aditya
```

### umask — Default Permissions

```bash
# umask defines what permissions are REMOVED when creating files
# Default umask: 022
# File created: 666 - 022 = 644 (rw-r--r--)
# Dir created:  777 - 022 = 755 (rwxr-xr-x)

umask              # show current umask
umask 027          # set umask: new files = 640, dirs = 750
                   # 640 = owner rw, group r, others nothing

# For security-sensitive apps:
umask 077          # files = 600, dirs = 700 (only owner can access)
```

---

## L4 — LINUX NETWORKING

### Network Interfaces and Routing

```bash
# Show network interfaces
ip addr show          # modern (preferred)
ip addr show eth0     # specific interface
ifconfig              # older, still common

# Show routing table
ip route show
route -n              # older syntax

# Add static route
ip route add 10.1.0.0/16 via 192.168.1.1
ip route del 10.1.0.0/16

# Show ARP table (IP → MAC mapping)
arp -a
ip neigh show

# DNS resolution
cat /etc/resolv.conf   # DNS server config
cat /etc/hosts         # local hostname overrides

# Test DNS
dig google.com
dig @8.8.8.8 google.com    # use specific DNS server
nslookup google.com
host google.com
```

### Ports and Connections

```bash
# What's listening on which port?
ss -tulnp               # modern (preferred)
netstat -tulnp          # older systems
lsof -i :8080           # what's using port 8080?
lsof -i tcp             # all TCP connections

# ss output columns:
# Netid State  Recv-Q Send-Q Local Address:Port  Peer Address:Port  Process
# tcp   LISTEN 0      128    0.0.0.0:8080       0.0.0.0:*          pid=1234

# Active connections
ss -an | grep ESTABLISHED
ss -s                   # connection summary

# Check if specific port is open (from this machine)
nc -zv localhost 8080
nc -zv 10.0.0.5 5432    # check postgres
nc -zvw 5 host 443       # with 5s timeout

# Check from another machine (is my service reachable?)
nc -zv external-host 80
telnet external-host 80  # older alternative
```

### iptables — Linux Firewall

```bash
# List all rules
iptables -L -n -v --line-numbers

# List specific chain
iptables -L INPUT -n -v

# CHAINS:
# INPUT:   incoming traffic TO this machine
# OUTPUT:  outgoing traffic FROM this machine
# FORWARD: traffic passing THROUGH (routing)

# Allow incoming SSH
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow established connections (stateful)
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Block specific IP
iptables -A INPUT -s 1.2.3.4 -j DROP

# Allow HTTP/HTTPS
iptables -A INPUT -p tcp -m multiport --dports 80,443 -j ACCEPT

# Default deny (put LAST)
iptables -A INPUT -j DROP

# Save rules (persist after reboot)
iptables-save > /etc/iptables/rules.v4  # Ubuntu/Debian
service iptables save                    # RHEL/CentOS

# Flush all rules (careful in production!)
iptables -F

# Real DevOps use: check if firewall blocking traffic
iptables -L INPUT -n -v | grep DROP
iptables -I INPUT -s 10.0.0.0/8 -j ACCEPT  # allow VPC traffic
```

### curl and HTTP Debugging

```bash
# Basic request
curl https://api.example.com/health

# Verbose (shows all headers)
curl -v https://api.example.com/health

# Show only headers
curl -I https://api.example.com

# POST with JSON
curl -X POST https://api.example.com/cases \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN" \
  -d '{"title":"Test case"}' \
  -v

# Follow redirects
curl -L http://example.com

# Timing breakdown (most useful for debugging latency)
curl -w "\nDNS: %{time_namelookup}s\nTCP: %{time_connect}s\nTLS: %{time_appconnect}s\nTTFB: %{time_starttransfer}s\nTotal: %{time_total}s\n" \
  -o /dev/null -s https://api.example.com

# Download file
curl -O https://example.com/file.tar.gz
curl -o output.tar.gz https://example.com/file.tar.gz

# With proxy
curl -x http://proxy:3128 https://api.example.com

# Ignore SSL errors (testing only)
curl -k https://self-signed.example.com

# Check certificate
curl -v --insecure https://example.com 2>&1 | grep -A5 "Server certificate"
```

### tcpdump — Packet Capture

```bash
# Capture all traffic on eth0
tcpdump -i eth0

# Capture traffic on specific port
tcpdump -i eth0 port 443

# Capture traffic to/from specific host
tcpdump -i eth0 host 10.0.0.5

# Capture and save to file
tcpdump -i eth0 port 5432 -w postgres.pcap

# Read captured file
tcpdump -r postgres.pcap

# Show packet contents (ASCII)
tcpdump -i eth0 port 80 -A

# Filter by multiple conditions
tcpdump -i eth0 "port 443 and host 10.0.0.5"

# TCP flags:
# [S]  = SYN
# [S.] = SYN-ACK
# [.]  = ACK
# [P.] = PUSH-ACK (data)
# [F.] = FIN-ACK
# [R]  = RST (connection refused or reset)

# Useful: watch DB connections
tcpdump -i eth0 port 5432 -n
# RST after SYN = DB refusing connection (check SG, PG_HBA)
# No response to SYN = firewall dropping packets
```

---

## L5 — SYSTEMD AND SERVICES

### Service Management

```bash
# Start/stop/restart/reload
systemctl start nginx
systemctl stop nginx
systemctl restart nginx      # stops then starts (brief downtime)
systemctl reload nginx       # reload config without restart (no downtime)
systemctl status nginx       # detailed status

# Enable/disable (autostart on boot)
systemctl enable nginx       # start on boot
systemctl disable nginx      # don't start on boot
systemctl is-enabled nginx   # check if enabled

# Combined (enable + start)
systemctl enable --now nginx

# List all services
systemctl list-units --type=service
systemctl list-units --type=service --state=failed

# Reload systemd after editing unit files
systemctl daemon-reload
```

### Creating a systemd Unit File

```bash
# Create unit file for your app
cat > /etc/systemd/system/judicial-api.service << 'EOF'
[Unit]
Description=Judicial Solutions API
Documentation=https://judicialsolutions.in/docs
After=network.target postgresql.service    # start after these
Wants=postgresql.service                   # soft dependency

[Service]
Type=simple
User=appuser
Group=appgroup
WorkingDirectory=/app/judicial-api

# Environment variables
Environment=ENVIRONMENT=production
Environment=LOG_LEVEL=info
EnvironmentFile=/etc/judicial-api/env     # load from file

# Start command
ExecStart=/usr/bin/python3 -m uvicorn src.main:app --host 0.0.0.0 --port 8080

# Restart behavior
Restart=always                            # restart if crashes
RestartSec=5s                             # wait 5s before restart
StartLimitInterval=60s                    # within 60 seconds...
StartLimitBurst=5                         # ...only try 5 times

# Resource limits
LimitNOFILE=65536                         # max open files
MemoryLimit=1G                            # max memory (systemd cgroup)
CPUQuota=200%                             # max 2 CPU cores

# Security hardening
ProtectSystem=strict                      # read-only filesystem
ProtectHome=true                          # no access to /home
PrivateTmp=true                           # private /tmp
NoNewPrivileges=true                      # can't gain more privileges

# Graceful shutdown
ExecStop=/bin/kill -s TERM $MAINPID
TimeoutStopSec=30                         # 30s to stop gracefully, then SIGKILL
KillSignal=SIGTERM

# Logging (to journald)
StandardOutput=journal
StandardError=journal
SyslogIdentifier=judicial-api

[Install]
WantedBy=multi-user.target               # start in normal multi-user mode
EOF

# Enable and start
systemctl daemon-reload
systemctl enable --now judicial-api
systemctl status judicial-api
```

### journalctl — Reading Logs

```bash
# Show all logs for a service
journalctl -u judicial-api

# Follow live (like tail -f)
journalctl -u judicial-api -f

# Last 100 lines
journalctl -u judicial-api -n 100

# Logs since specific time
journalctl -u judicial-api --since "2024-03-22 10:00:00"
journalctl -u judicial-api --since "1 hour ago"
journalctl -u judicial-api --since today

# Filter by priority
journalctl -u judicial-api -p err          # errors only
journalctl -u judicial-api -p warning      # warnings and above

# All boots
journalctl --list-boots

# Current boot logs
journalctl -b

# Kernel messages
journalctl -k

# Disk usage
journalctl --disk-usage

# Vacuum old logs
journalctl --vacuum-time=7d                # keep last 7 days
journalctl --vacuum-size=500M              # keep max 500MB
```

---

## L6 — SHELL SCRIPTING

### Bash Fundamentals

```bash
#!/bin/bash
# Shebang: tells OS which interpreter to use

# Strict mode (ALWAYS use for production scripts)
set -euo pipefail
# -e: exit on any error
# -u: error on undefined variables
# -o pipefail: pipe fails if any command fails

# Variables
NAME="judicial"
VERSION=1.3
TIMESTAMP=$(date +%Y%m%d_%H%M%S)    # command substitution
EMPTY=""
ARRAY=(one two three)

# Quoting matters:
echo $NAME       # word splitting — dangerous if NAME has spaces
echo "$NAME"     # always quote variables
echo "${NAME}"   # same, explicit delimiters

# Array access
echo "${ARRAY[0]}"        # first element
echo "${ARRAY[@]}"        # all elements
echo "${#ARRAY[@]}"       # array length

# String operations
echo "${NAME^^}"           # uppercase: JUDICIAL
echo "${NAME:0:3}"         # substring: jud
echo "${NAME/judicial/app}" # replace
FILE="/path/to/file.txt"
echo "${FILE##*/}"         # basename: file.txt
echo "${FILE%/*}"          # dirname: /path/to
echo "${FILE%.txt}"        # remove extension: /path/to/file
```

### Conditionals and Loops

```bash
# If statements
if [ -f /etc/nginx/nginx.conf ]; then
    echo "Config exists"
elif [ -d /etc/nginx ]; then
    echo "Directory exists but no config"
else
    echo "Nginx not configured"
fi

# Test operators:
# -f file    → is regular file
# -d dir     → is directory
# -e path    → exists (any type)
# -r file    → is readable
# -w file    → is writable
# -x file    → is executable
# -s file    → exists and not empty
# -z string  → string is empty
# -n string  → string is not empty
# str1 = str2   → strings equal
# str1 != str2  → strings not equal
# int1 -eq int2 → integers equal
# int1 -gt int2 → int1 > int2
# int1 -lt int2 → int1 < int2

# Double brackets (preferred, more features)
if [[ "$NAME" == "judicial"* ]]; then  # wildcard matching
    echo "Starts with judicial"
fi

if [[ "$STATUS" =~ ^[0-9]+$ ]]; then  # regex matching
    echo "Status is numeric"
fi

# For loops
for i in {1..10}; do
    echo "Iteration $i"
done

for file in /var/log/*.log; do
    echo "Processing: $file"
    gzip "$file"
done

# Array loop
SERVICES=(nginx postgresql redis)
for service in "${SERVICES[@]}"; do
    systemctl restart "$service"
    echo "Restarted: $service"
done

# While loop
while true; do
    if curl -sf http://localhost:8080/health; then
        echo "Service is up"
        break
    fi
    echo "Waiting for service..."
    sleep 5
done

# Loop with counter
count=0
while [[ $count -lt 10 ]]; do
    echo "Count: $count"
    ((count++))
done
```

### Functions and Error Handling

```bash
#!/bin/bash
set -euo pipefail

# Function definition
log() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a /var/log/deploy.log
}

check_dependency() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        log "ERROR" "Required command not found: $cmd"
        exit 1
    fi
    log "INFO" "Found dependency: $cmd"
}

deploy_service() {
    local service="$1"
    local version="$2"
    
    log "INFO" "Deploying $service version $version"
    
    # Return value via global variable (bash doesn't have real return values)
    DEPLOY_STATUS="success"
    
    # Return exit code
    return 0
}

# Trap — run cleanup on exit (even on error)
cleanup() {
    local exit_code=$?
    log "INFO" "Cleaning up temporary files..."
    rm -rf /tmp/deploy_*
    if [[ $exit_code -ne 0 ]]; then
        log "ERROR" "Script failed with exit code: $exit_code"
    fi
}
trap cleanup EXIT          # run on any exit
trap 'log "ERROR" "Interrupted"' INT TERM  # run on Ctrl+C or kill

# Main script
main() {
    log "INFO" "Starting deployment"
    
    check_dependency docker
    check_dependency kubectl
    check_dependency aws
    
    deploy_service "judicial-api" "1.3.0"
    log "INFO" "Deployment complete"
}

main "$@"
```

### Practical DevOps Scripts

```bash
#!/bin/bash
# Health check script — waits for service to be ready

set -euo pipefail

URL="${1:-http://localhost:8080/health}"
MAX_RETRIES="${2:-30}"
SLEEP_INTERVAL="${3:-5}"

echo "Waiting for service at: $URL"

for attempt in $(seq 1 "$MAX_RETRIES"); do
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL" || echo "000")
    
    if [[ "$HTTP_STATUS" == "200" ]]; then
        echo "Service is healthy (attempt $attempt)"
        exit 0
    fi
    
    echo "Attempt $attempt/$MAX_RETRIES: HTTP $HTTP_STATUS — retrying in ${SLEEP_INTERVAL}s"
    sleep "$SLEEP_INTERVAL"
done

echo "ERROR: Service not healthy after $MAX_RETRIES attempts"
exit 1

---

#!/bin/bash
# Rotate logs older than 7 days

LOG_DIR="/var/log/judicial-api"
RETENTION_DAYS=7
ARCHIVE_DIR="/mnt/s3/logs"

find "$LOG_DIR" -name "*.log" -mtime +"$RETENTION_DAYS" | while read -r logfile; do
    gzip "$logfile"
    aws s3 cp "${logfile}.gz" "s3://judicial-logs/archive/"
    rm "${logfile}.gz"
    echo "Archived: $logfile"
done

---

#!/bin/bash
# Deploy with rollback

DEPLOYMENT="judicial-api"
NAMESPACE="production"
NEW_IMAGE="$1"

# Save current image for rollback
CURRENT_IMAGE=$(kubectl get deployment "$DEPLOYMENT" \
    -n "$NAMESPACE" \
    -o jsonpath='{.spec.template.spec.containers[0].image}')

echo "Current: $CURRENT_IMAGE"
echo "Deploying: $NEW_IMAGE"

# Deploy
kubectl set image "deployment/$DEPLOYMENT" \
    "$DEPLOYMENT=$NEW_IMAGE" \
    -n "$NAMESPACE"

# Wait for rollout
if ! kubectl rollout status "deployment/$DEPLOYMENT" \
    -n "$NAMESPACE" --timeout=5m; then
    echo "Rollout failed — rolling back to $CURRENT_IMAGE"
    kubectl rollout undo "deployment/$DEPLOYMENT" -n "$NAMESPACE"
    exit 1
fi

echo "Deployment successful"
```

### Cron Jobs

```bash
# Cron format: minute hour day month weekday
# *  *  *  *  *  command
# │  │  │  │  └── weekday (0-7, 0=Sun, 7=Sun)
# │  │  │  └───── month (1-12)
# │  │  └──────── day of month (1-31)
# │  └─────────── hour (0-23)
# └────────────── minute (0-59)

# Edit cron jobs
crontab -e

# Examples:
# Every minute:
* * * * * /opt/scripts/health-check.sh

# Every 5 minutes:
*/5 * * * * /opt/scripts/check-disk.sh

# At 2am every day:
0 2 * * * /opt/scripts/rotate-logs.sh

# At 2am every Sunday:
0 2 * * 0 /opt/scripts/weekly-backup.sh

# Weekdays at 8am:
0 8 * * 1-5 /opt/scripts/morning-report.sh

# Every hour on weekdays:
0 * * * 1-5 /opt/scripts/sync-data.sh

# Redirect output (always do this):
0 2 * * * /opt/scripts/backup.sh >> /var/log/backup.log 2>&1

# List crontab
crontab -l

# System-wide cron:
/etc/cron.d/          ← drop cron files here
/etc/cron.daily/      ← scripts run daily
/etc/cron.hourly/     ← scripts run hourly
```

---

## L7 — PERFORMANCE AND DEBUGGING

### System Performance Tools

```bash
# top — real-time overview (already covered)
# Focus on:
# load average > number of CPUs → system overloaded
# wa% (iowait) > 20% → disk I/O bottleneck
# si/so (swap in/out) > 0 → using swap = RAM problem

# vmstat — virtual memory statistics
vmstat 1 10    # sample every 1 second, 10 times

# Columns:
# r  = runnable processes (waiting for CPU)
# b  = blocked processes (waiting for I/O)
# si = pages swapped in (memory → disk)
# so = pages swapped out (disk → memory)
# us = user CPU%
# sy = system CPU%
# id = idle CPU%
# wa = iowait CPU%

# iostat — I/O statistics
iostat -x 1 5    # extended stats, 1 second interval, 5 times

# Key columns:
# %util      = disk utilization (>80% = problem)
# await      = average wait time ms (>20ms = slow disk)
# r/s, w/s   = reads/writes per second

# free — memory usage
free -h
# Output:
#               total    used    free  shared  buff/cache  available
# Mem:          7.5Gi   3.2Gi   1.1Gi  256Mi    3.2Gi      4.0Gi
# Swap:         2.0Gi    0B     2.0Gi

# "available" is what matters — includes reclaimable cache
# Swap usage > 0 = system running out of RAM

# dmesg — kernel messages (often shows OOM kills)
dmesg | tail -20
dmesg | grep -i "oom\|killed\|error\|warn"
dmesg --since "1 hour ago"
```

### strace — System Call Tracing

```bash
# Trace system calls made by a process
strace -p 1234           # attach to running process
strace python app.py     # trace from start

# Count system calls
strace -c python app.py  # show stats at end

# Filter specific calls
strace -e open,read,write python app.py   # only file operations
strace -e network python app.py           # only network calls

# Trace with timestamps
strace -t python app.py  # add timestamp
strace -T python app.py  # show time spent in each call

# Trace child processes too
strace -f python app.py  # follow forks

# Common use: "why is my script slow?"
strace -c ./slow_script.sh
# Shows: which syscalls take most time
# Often: too many stat() or open() calls (file descriptor leak)

# Trace file access
strace -e trace=file ls /tmp
# Shows every file/dir accessed
```

### lsof — List Open Files

```bash
# List all open files (everything is a file in Linux)
lsof | head -20

# Files opened by specific process
lsof -p 1234

# What process is using a port
lsof -i :8080
lsof -i :443

# What process has a file open
lsof /var/log/app.log

# Files opened by specific user
lsof -u appuser

# Network connections by specific process
lsof -i -p 1234

# Count open file descriptors per process
lsof | awk '{print $2}' | sort | uniq -c | sort -rn | head -10

# Check file descriptor limits (ulimit)
ulimit -n                    # max open files for current shell
cat /proc/sys/fs/file-max    # system-wide max
cat /proc/1234/limits        # limits for specific PID
```

### Diagnosing a Slow Server — Complete Flow

```bash
# Step 1: What's the load?
uptime
# load average: 8.5, 6.2, 4.1 ← 8.5 in last minute (very high)

# Step 2: Is it CPU, memory, or I/O?
top
# High %us = CPU-bound (your app is the problem)
# High %wa = I/O-bound (disk is slow)
# High si/so in vmstat = memory-bound (swapping)

# Step 3: Which process is causing it?
ps aux --sort=-%cpu | head -5    # top CPU consumers
ps aux --sort=-%mem | head -5    # top memory consumers

# Step 4: What is it doing?
strace -p PID -c              # what syscalls?
lsof -p PID | wc -l           # how many open files?

# Step 5: Is it network-related?
ss -an | grep ESTABLISHED | wc -l  # how many connections?
netstat -s | grep -i error         # network errors?

# Step 6: Is it disk-related?
iostat -x 1 3
df -h                         # disk space full?
df -i                         # inodes full?

# Step 7: Check logs
journalctl -u myapp --since "10 minutes ago"
tail -100 /var/log/app.log | grep -i "error\|slow\|timeout"
```

---

## L8 — LINUX INTERVIEW SCENARIOS

**Q: What is a zombie process and how do you handle it?**
```
Zombie = finished process whose parent hasn't collected its exit status.
Shows as Z in ps aux.

Takes: no CPU, no memory — only a PID slot.
Problem: too many zombies exhausts PID table → can't create new processes.

Cannot kill a zombie directly (it's already dead).
Fix: kill the PARENT process — parent cleanup reaps its zombies.

Find: ps aux | grep Z
      Parent PID: ps -o ppid= -p ZOMBIE_PID
Kill parent: kill PARENT_PID
```

**Q: How do you find which process is using port 8080?**
```
ss -tulnp | grep :8080
lsof -i :8080
fuser 8080/tcp
```

**Q: Server is running out of disk space. How do you diagnose?**
```
df -h           → which filesystem is full?
du -sh /var/*   → which directory is largest?
du -sh /var/log/* | sort -rh | head -10  → largest logs?
find / -size +1G -type f   → files > 1GB
lsof | grep deleted | awk '{print $7, $9}' | sort -rn | head
# ↑ find deleted files still held open by processes (common gotcha!)
```

**Q: What is the difference between SIGTERM and SIGKILL?**
```
SIGTERM (15): polite request to stop
  Process CAN catch it → run cleanup → exit gracefully
  Used by: systemctl stop, K8s pod termination, Ctrl+C
  
SIGKILL (9): unconditional kill
  Process CANNOT catch or ignore
  OS kills it immediately — no cleanup
  May leave: tmp files, corrupted state, open connections
  Use as last resort only
```

**Q: How do you run a command after logout (background process)?**
```
nohup command &         # immune to hangup, output to nohup.out
command &               # background, dies on logout
screen / tmux           # persistent terminal session
systemd service         # proper production solution
```

---

# ══════════════════════════════════════
# GIT
# ══════════════════════════════════════

## G1 — GIT INTERNALS

### How Git Stores Data

```
Git is a content-addressable filesystem.
Everything stored as objects with SHA1 hash as key.

4 object types:
  blob:   file content
  tree:   directory (list of blobs + trees with names)
  commit: snapshot (points to tree + parent commit + message)
  tag:    named commit reference

Example: you commit one file (hello.py)

Blob:   hash(content of hello.py)
Tree:   hash(blob_hash + "hello.py" + permissions)
Commit: hash(tree_hash + parent_hash + author + message + timestamp)

This means:
  Same content = same hash (deduplication)
  Any change = new hash = nothing overwrites old data
  Hash chain: commit → tree → blobs (tamper-evident)
```

```bash
# Explore git internals
git cat-file -t abc1234    # what type is this object?
git cat-file -p abc1234    # print contents of object
git ls-tree HEAD           # list tree at HEAD

# Where git stores things:
.git/
├── HEAD           ← current branch pointer
├── index          ← staging area (binary)
├── objects/       ← all objects (blobs, trees, commits)
│   ├── ab/
│   │   └── cd1234...  ← first 2 chars = dir, rest = filename
│   └── pack/      ← packed objects (efficient storage)
├── refs/
│   ├── heads/     ← local branches
│   │   └── main   ← "main" contains commit hash
│   ├── remotes/   ← remote branches
│   └── tags/      ← tags
└── config         ← repo configuration
```

### Git Areas — The Three Trees

```
Working Directory   Staging Area (Index)   Repository (.git)
     │                      │                      │
     │  git add             │  git commit           │
     │─────────────────────►│──────────────────────►│
     │                      │                      │
     │◄─────────────────────│◄──────────────────────│
     │  git checkout        │  git reset HEAD       │

Working Directory: files you see and edit
Staging Area:      files prepared for next commit (git add)
Repository:        committed history (git commit)

This is WHY:
  Edited file but not git add → not in staging
  git add but not git commit → in staging, not in history
  git commit → permanently in history (almost — see reflog)
```

---

## G2 — BRANCHING STRATEGIES

### GitFlow

```
Branches:
  main:     production code (only merge from release/* or hotfix/*)
  develop:  integration branch (feature/* branches merge here)
  feature/*: individual features (branch from develop)
  release/*: release preparation (branch from develop)
  hotfix/*:  urgent production fixes (branch from main)

Flow:
  feature/case-priority ──► develop ──► release/1.3 ──► main
                                                      ──► develop (back-merge)
  hotfix/urgent-fix ──► main ──► develop (back-merge)

Pros:
  Clear structure, good for versioned software
  Release branches allow stabilisation without blocking new features
  
Cons:
  Complex, many long-lived branches
  Merge conflicts accumulate
  Slow — code takes long to reach main
  
Use for:
  Mobile apps (release cycles matter)
  Libraries with versioned releases
  Large teams with formal release process
```

### Trunk-Based Development

```
Branches:
  main (trunk): always deployable, everyone merges here daily
  feature/*:    short-lived (1-3 days MAX), then merged to main
  release/*:    optional, cut from main for release

Flow:
  feature/quick-fix → main (merge within 1-2 days)
  
Feature flags: incomplete features deployed but hidden
  if os.environ.get('FEATURE_PRIORITY_FIELD') == 'true':
      # new code
  else:
      # old code
  
  Deploy to main hidden → enable flag for 5% users →
  monitor → 100% → remove flag + old code

Pros:
  Simple, fast, forces small commits
  CI/CD is easier (one branch to test)
  Fewer merge conflicts
  
Cons:
  Requires feature flags for incomplete work
  Requires excellent CI/CD + test coverage
  Harder if team is large and undisciplined

Use for:
  Web apps / SaaS (continuous deployment)
  Small-medium teams
  High deployment frequency goals
```

### Which One for Your Resume?

```
You use a simplified trunk-based approach:
  feature branches merged to main → auto-deploy to dev/staging
  main → production (manual approval)

Say in interview:
  "We use trunk-based development — feature branches stay
   short-lived (1-3 days), merged to main frequently.
   CI runs on every push. Main auto-deploys to staging.
   Production requires manual approval.
   This gives us daily deployments with low merge conflict overhead."
```

---

## G3 — MERGE vs REBASE

### The Core Difference

```
Scenario:
  main:    A → B → C
  feature: A → B → D → E

MERGE:
  git checkout main
  git merge feature
  
  Result: A → B → C → F  (F is merge commit)
                ↑
                D → E ─┘
  
  Preserves: complete history, when branches diverged, all commits
  Creates: merge commit (shows integration point)
  Non-destructive: original commits unchanged
  
REBASE:
  git checkout feature
  git rebase main
  
  Result: A → B → C → D' → E'  (D' and E' are NEW commits)
  
  Then: git checkout main && git merge feature (fast-forward)
  Result: A → B → C → D' → E'  (linear!)
  
  Creates: linear history (looks like everything happened in sequence)
  Rewrites: commit hashes (D becomes D', E becomes E')
  Cleaner: no merge commits
```

### When to Use Which

```
MERGE:
  ✅ Merging completed feature into main/develop
  ✅ Public/shared branches (never rebase these)
  ✅ When you want to preserve exact history
  ✅ Team is unfamiliar with rebasing
  
  git merge feature/case-priority      # preserves feature branch history

REBASE:
  ✅ Updating your LOCAL feature branch with latest main changes
  ✅ Cleaning up messy local commits before PR
  ✅ Interactive rebase to squash/edit commits before sharing
  ❌ NEVER on shared/public branches (rewrites history others have)
  
  git rebase main                      # update feature with main's latest
  git rebase -i HEAD~5                 # interactive: edit last 5 commits
```

### Interactive Rebase — Clean Up Commits

```bash
# Clean up last 5 commits before creating PR
git rebase -i HEAD~5

# Opens editor showing:
# pick abc1234 Add priority field to model
# pick def5678 Fix typo
# pick ghi9012 Add test
# pick jkl3456 WIP
# pick mno7890 Fix test + add migration

# Commands you can use:
# pick   = keep as-is
# reword = keep commit, edit message
# edit   = pause here to amend the commit
# squash = merge into previous commit (keep both messages)
# fixup  = merge into previous (discard this message)
# drop   = delete this commit entirely

# Practical: squash WIP commits, clean up messages
# pick abc1234 Add priority field to model
# fixup def5678 Fix typo          ← merge into abc1234
# pick ghi9012 Add test
# fixup jkl3456 WIP               ← merge into ghi9012
# reword mno7890 Fix test + add migration

# Result: 3 clean commits instead of 5 messy ones
# DO THIS before creating PRs for cleaner review history
```

### The Golden Rule

```
NEVER rebase commits that exist on a remote shared branch.

Why:
  You rebased → your commits have NEW hashes (D' instead of D)
  Your colleague: still has old hashes (D)
  You push (force push) → overwrites remote with new hashes
  Colleague pulls → git is confused (two different D commits)
  → Chaos, conflicts, lost work

Rule:
  Feature branches you haven't pushed yet → freely rebase
  After push → no rebase (unless you own the branch alone)
  main/develop/release → NEVER rebase
```

---

## G4 — UNDOING THINGS

### The Complete Undo Guide

```
Scenario → Command → Effect

Staged file, want to unstage:
  git restore --staged file.py     # unstage, keep changes in working dir
  git reset HEAD file.py           # older syntax, same effect

Changed file, want to discard changes:
  git restore file.py              # discard working dir changes
  git checkout -- file.py          # older syntax

Last commit was wrong, not pushed yet:
  git reset --soft HEAD~1          # undo commit, keep changes staged
  git reset --mixed HEAD~1         # undo commit, keep changes in working dir
  git reset --hard HEAD~1          # undo commit AND discard all changes

Multiple commits wrong, not pushed:
  git reset --hard HEAD~3          # go back 3 commits, discard all

Committed something but already pushed (SAFE way):
  git revert abc1234               # creates NEW commit that undoes abc1234
  git push                         # safe to push (history preserved)
  # Use this for public branches — never rewrites history

Wrong message on last commit (not pushed):
  git commit --amend -m "Correct message"

Forgot to add a file to last commit:
  git add forgotten-file.py
  git commit --amend --no-edit    # amend without changing message
```

### git reset — The Three Modes

```
git reset HEAD~1

--soft:   moves HEAD back, KEEPS changes staged
          Working dir: unchanged
          Staging:     previous commit's changes back in staging
          Use: "undo commit but keep work ready to recommit"

--mixed:  moves HEAD back, UNSTAGES changes (default)
(default) Working dir: unchanged
          Staging:     empty (changes back in working dir)
          Use: "undo commit and unstage, let me re-stage selectively"

--hard:   moves HEAD back, DISCARDS all changes
          Working dir: reset to that commit's state
          Staging:     reset
          Use: "completely undo last commit, throw away all changes"
          ⚠️ DANGEROUS — work is lost (unless in reflog)
```

### git reflog — Your Safety Net

```bash
# reflog records every time HEAD moves
# Even after git reset --hard, commits are in reflog for 90 days

git reflog
# Output:
# abc1234 HEAD@{0}: reset: moving to HEAD~1
# def5678 HEAD@{1}: commit: Add priority field
# ghi9012 HEAD@{2}: commit: Fix tests
# jkl3456 HEAD@{3}: checkout: moving to main

# "I did git reset --hard and lost commits!"
# Step 1: find the lost commit in reflog
git reflog | grep "Add priority"

# Step 2: restore it
git reset --hard def5678      # go back to that commit
# OR create a branch from it:
git checkout -b recovery def5678

# reflog is LOCAL only — doesn't push to remote
# Commits stay in reflog for 90 days (gc.reflogExpire)
```

---

## G5 — ADVANCED GIT

### Cherry-Pick — Take One Commit

```bash
# Apply a specific commit from another branch to current branch
git cherry-pick abc1234

# Multiple commits
git cherry-pick abc1234 def5678

# Range of commits
git cherry-pick abc1234^..ghi9012   # from abc to ghi (inclusive)

# Cherry-pick without committing (stage only)
git cherry-pick -n abc1234

# Use case:
# Hotfix committed to feature branch by mistake
# Need it in main ASAP without merging the whole feature

# Or: backport a bug fix from main to older release branch
git checkout release/1.2
git cherry-pick abc1234   # apply the fix from main
```

### git stash — Temporary Storage

```bash
# Save current changes (working dir + staging)
git stash

# Save with message
git stash push -m "WIP: case priority feature"

# List stashes
git stash list
# stash@{0}: WIP: case priority feature
# stash@{1}: On main: quick fix attempt

# Apply latest stash (keep stash)
git stash apply

# Apply and remove latest stash
git stash pop

# Apply specific stash
git stash apply stash@{1}

# Show stash contents
git stash show -p stash@{0}

# Delete specific stash
git stash drop stash@{0}

# Delete all stashes
git stash clear

# Stash specific files only
git stash push file1.py file2.py

# Stash including untracked files
git stash push -u

# Use case:
# Mid-feature → urgent bug report → stash → fix bug → pop stash → continue
```

### git bisect — Binary Search for Bugs

```bash
# "This worked in v1.0, now it's broken. Which commit broke it?"
git bisect start
git bisect bad                   # current commit is broken
git bisect good v1.0             # v1.0 tag was working

# Git checks out middle commit
# Test: does the bug exist?
git bisect good    # no bug here
# Or:
git bisect bad     # bug exists here

# Git narrows down (binary search across 1000 commits = 10 steps)
# Eventually: "abc1234 is the first bad commit"

# Find: what changed in that commit
git show abc1234

# Clean up
git bisect reset    # return to original state

# Automate with a test script
git bisect run ./test-for-bug.sh
# Script: exit 0 = good, exit 1 = bad
```

### Git Hooks

```bash
# Hooks = scripts that run automatically on git events
# Location: .git/hooks/

# Pre-commit: run before commit is created
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Lint Python files before committing
git diff --cached --name-only --diff-filter=ACM | grep '\.py$' | xargs flake8
if [ $? -ne 0 ]; then
    echo "Linting failed. Fix errors before committing."
    exit 1
fi
EOF
chmod +x .git/hooks/pre-commit

# Commit-msg: validate commit message format
cat > .git/hooks/commit-msg << 'EOF'
#!/bin/bash
# Enforce conventional commits: feat|fix|docs|chore: message
if ! head -1 "$1" | grep -qE "^(feat|fix|docs|chore|refactor|test|ci|style)(\(.+\))?: .{1,72}$"; then
    echo "Invalid commit message. Use: feat|fix|docs: message"
    exit 1
fi
EOF
chmod +x .git/hooks/commit-msg

# Pre-push: run tests before pushing
cat > .git/hooks/pre-push << 'EOF'
#!/bin/bash
pytest tests/ || { echo "Tests failed. Push aborted."; exit 1; }
EOF
chmod +x .git/hooks/pre-push

# Share hooks with team (hooks are not committed by default):
mkdir -p .githooks
# Put hooks in .githooks/ and commit them
git config core.hooksPath .githooks  # configure git to use this path
# Add to setup script or Makefile for new developers
```

---

## G6 — GIT IN CI/CD

### Tagging

```bash
# Lightweight tag (just a pointer to a commit)
git tag v1.3.0

# Annotated tag (has metadata — use these for releases)
git tag -a v1.3.0 -m "Release 1.3.0 — Add case priority feature"

# Tag specific commit
git tag -a v1.3.0 abc1234 -m "Release 1.3.0"

# List tags
git tag
git tag -l "v1.*"   # filter

# Push tags (tags NOT pushed by default)
git push origin v1.3.0        # push specific tag
git push origin --tags        # push all tags

# Delete tag
git tag -d v1.3.0             # delete locally
git push origin :v1.3.0       # delete from remote

# In CI/CD:
# GitHub Actions trigger on tags:
on:
  push:
    tags: ['v*']    # triggers on any v1.x.x tag push
```

### Protected Branches

```
Configure in GitHub/GitLab:
  main branch:
    ✓ Require pull request before merging
    ✓ Require N approvals
    ✓ Require status checks (CI must pass)
    ✓ Require branches to be up to date
    ✓ Dismiss stale reviews when new commits pushed
    ✓ Require signed commits
    ✗ Allow force push (NEVER allow on main)
    ✗ Allow deletions (NEVER)

This enforces:
  No direct push to main — must go through PR
  CI must pass before merge
  Code review required
  History cannot be rewritten
```

### Commit Signing (GPG)

```bash
# Verify commits came from who they claim
# Without signing: anyone can commit as "Linus Torvalds"

# Setup GPG signing
gpg --gen-key
git config --global user.signingkey YOUR_KEY_ID
git config --global commit.gpgsign true

# Signed commit
git commit -S -m "feat: add priority field"

# Verify signatures
git log --show-signature
git verify-commit abc1234

# In GitHub: "Verified" badge on commits
# In CI: require signed commits for release tags
```

---

## G7 — GITOPS

### GitOps Principles

```
GitOps = Git as single source of truth for infrastructure

4 core principles:
  1. Declarative: system state described declaratively (YAML/HCL)
  2. Versioned: all changes via git (audit trail, history)
  3. Automatic: software agents apply desired state automatically
  4. Self-healing: agents continuously reconcile actual vs desired

Without GitOps:
  kubectl apply manually → no audit trail
  Terraform apply locally → state conflicts
  "Who changed prod at 2am?" → nobody knows

With GitOps:
  All changes via PR → reviewed, approved, tracked
  Merge to main → ArgoCD applies automatically
  Rollback = git revert → ArgoCD reverts automatically
  "Who changed prod?" → git blame + PR history
```

### Git Repository Structure for GitOps

```
infra-repo/
├── apps/
│   ├── judicial-api/
│   │   ├── base/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   └── kustomization.yaml
│   │   └── overlays/
│   │       ├── dev/
│   │       │   └── kustomization.yaml  # patch: replicas=1, image=:dev
│   │       ├── staging/
│   │       │   └── kustomization.yaml  # patch: replicas=2
│   │       └── production/
│   │           └── kustomization.yaml  # patch: replicas=6, resources bigger
│   └── judicial-frontend/
│       └── ...
└── infrastructure/
    ├── vpc/
    ├── eks/
    └── rds/

CI pipeline:
  1. Build image → push to ECR with git SHA tag
  2. Update kustomization.yaml: image: judicial-api:abc1234f
  3. git commit + push to infra-repo
  4. ArgoCD detects change → applies to cluster
  5. Deployment rolls out → pods updated
```

### ArgoCD Workflow

```bash
# ArgoCD watches git repo
# Compares: git state vs cluster state
# If different → "OutOfSync" → auto-apply (if configured)

# ArgoCD CLI
argocd app get judicial-api           # app status
argocd app sync judicial-api          # force sync
argocd app rollback judicial-api 3    # rollback to previous

# Manual override prevention:
# selfHeal: true → ArgoCD reverts manual kubectl changes
# If you kubectl apply manually → ArgoCD detects drift → reverts

# App definition
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: judicial-api
spec:
  source:
    repoURL: https://github.com/org/infra-repo
    path: apps/judicial-api/overlays/production
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true          # delete removed resources
      selfHeal: true       # revert manual changes
```

---

## G8 — GIT INTERVIEW QUESTIONS

**Q1: What is the difference between git merge and git rebase?**
```
Merge: combines two branches, creates a merge commit, preserves history
Rebase: moves commits on top of another branch, creates linear history, rewrites hashes

Use merge for: integrating completed features into main/develop
Use rebase for: updating local feature branch with latest main (before PR)

Golden rule: never rebase shared/public branches
```

**Q2: How do you undo a commit that has already been pushed?**
```
SAFE way: git revert abc1234
  Creates a NEW commit that reverses the changes
  History preserved — old commit still exists
  Safe to push — doesn't rewrite history

UNSAFE way (only if you own the branch alone):
  git reset --hard HEAD~1
  git push --force-with-lease  # safer than --force
  Rewrites history — if anyone pulled, they have problems

For public/shared branches: ALWAYS use git revert
```

**Q3: What is git stash and when would you use it?**
```
git stash temporarily saves changes without committing.

Use when:
  Mid-feature work → urgent bug in different branch
  1. git stash          (save current work)
  2. git checkout main  (switch to main)
  3. fix bug, commit
  4. git checkout feature
  5. git stash pop      (restore saved work)

Or: experimenting → not working → stash → try different approach
```

**Q4: What is git cherry-pick?**
```
Apply a specific commit from one branch to another.

Use cases:
  Hotfix committed to wrong branch → cherry-pick to correct branch
  Backport fix: cherry-pick from main to release/1.2 branch
  Take one specific feature without merging the whole branch

git cherry-pick abc1234
```

**Q5: How do you find which commit introduced a bug?**
```
git bisect — binary search through commit history

git bisect start
git bisect bad           # current = broken
git bisect good v1.0     # v1.0 = working

Git checks out middle commit. Test. Mark good/bad.
Git narrows down. After ~10 steps → found the bad commit.

git bisect run ./test.sh   # automate if you have a test
git bisect reset           # clean up
```

**Q6: What is the difference between git fetch and git pull?**
```
git fetch: downloads changes from remote, does NOT apply them
           Updates remote-tracking branches (origin/main)
           Safe — doesn't touch your working directory

git pull: git fetch + git merge (or rebase if configured)
          Downloads AND applies changes immediately

Best practice: git fetch → inspect → git merge
               Safer than blindly pulling
               
git pull --rebase: fetch + rebase instead of merge (linear history)
```

**Q7: How do you resolve a merge conflict?**
```
1. git status              → see conflicted files
2. Open file — look for:
   <<<<<<< HEAD
   your changes
   =======
   their changes
   >>>>>>> feature-branch

3. Edit file: keep correct version (or combine both)
   Remove conflict markers completely

4. git add resolved-file.py
5. git commit              → completes the merge

Tools:
  git mergetool            → opens visual merge tool
  VS Code                  → built-in merge editor
```

**Q8: Explain GitFlow branching strategy.**
```
main:     production code
develop:  integration branch
feature/: new features (branch from develop, merge back to develop)
release/: release prep (branch from develop, merge to main + develop)
hotfix/:  urgent fixes (branch from main, merge to main + develop)

Good for: versioned software, formal releases
Bad for:  high-frequency deployment (too many long-lived branches)
```

**Q9: What is git reflog and when would you use it?**
```
reflog records every movement of HEAD — even after resets.
Your safety net for 90 days.

Use when: "I did git reset --hard and lost work"
git reflog → find the lost commit → git reset --hard COMMIT_HASH

OR: "I deleted a branch by mistake"
git reflog → find last commit on that branch → git checkout -b recovered HASH
```

**Q10: How do you squash multiple commits into one?**
```
Interactive rebase:
git rebase -i HEAD~5    # last 5 commits

In editor:
pick abc1234 First commit
squash def5678 Second commit    # squash into previous
fixup ghi9012 Fix typo          # squash + discard message

Result: one clean commit with combined changes

Or: squash merge when merging PR
git merge --squash feature-branch
git commit -m "Add case priority feature"
```

---

## QUICK REFERENCE

### Linux Commands Cheatsheet

```bash
PROCESSES:
  ps aux            → all processes
  top / htop        → real-time
  kill -15 PID      → graceful stop
  kill -9 PID       → force kill
  kill -HUP PID     → reload config
  ps aux | grep Z   → find zombies

DISK:
  df -h             → disk space
  df -i             → inodes
  du -sh dir/*      → dir sizes
  find / -size +1G  → large files

NETWORK:
  ss -tulnp         → listening ports
  lsof -i :8080     → port user
  nc -zv host port  → test connectivity
  curl -v URL       → HTTP debug
  tcpdump -i eth0   → packet capture

PERFORMANCE:
  vmstat 1          → CPU/memory/IO stats
  iostat -x 1       → disk IO
  strace -p PID     → syscall trace
  lsof -p PID       → open files

LOGS:
  journalctl -u svc -f    → follow service logs
  tail -f /var/log/app.log → follow log file
  grep -r "ERROR" /logs/   → search logs
```

### Git Commands Cheatsheet

```bash
DAILY:
  git status                → what's changed
  git add -p                → stage hunks interactively
  git commit -m "msg"       → commit
  git push origin branch    → push
  git pull --rebase         → pull with rebase

BRANCHING:
  git checkout -b feature   → create + switch branch
  git branch -d branch      → delete branch
  git branch -a             → list all branches
  git merge --no-ff branch  → merge with commit

REBASE:
  git rebase main           → update feature with main
  git rebase -i HEAD~5      → interactive rebase last 5

UNDO:
  git restore file          → discard working dir changes
  git restore --staged file → unstage
  git reset --soft HEAD~1   → undo commit, keep staged
  git reset --hard HEAD~1   → undo commit + discard changes
  git revert abc1234        → safe undo (new commit)
  git reflog                → see all history

ADVANCED:
  git stash                 → save work temporarily
  git stash pop             → restore saved work
  git cherry-pick abc1234   → apply specific commit
  git bisect start/good/bad → find bug commit
  git log --oneline --graph → visual history

TAGS:
  git tag -a v1.0 -m "msg" → annotated tag
  git push origin --tags    → push all tags
  git tag -d v1.0           → delete tag
```

### Branching Decision Tree

```
New feature:
  Long-lived (weeks)?     → feature/name branch
  Short (1-2 days)?       → feature/name → merge fast
  
Bug fix:
  Production urgent?      → hotfix/ from main
  Non-urgent?             → fix/ from develop
  
Is it safe to rebase?
  Not pushed yet?         → YES, freely rebase
  Pushed, only you use it? → YES, with --force-with-lease
  Pushed, team uses it?   → NO, use merge instead
  
Which undo command?
  Staged, not committed?  → git restore --staged
  Committed, not pushed?  → git reset
  Committed AND pushed?   → git revert (always)
```
