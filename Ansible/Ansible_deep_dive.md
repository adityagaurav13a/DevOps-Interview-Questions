# Ansible Complete Deep Dive
## Architecture + Inventory + Playbooks + Modules + Roles + Vault + CI/CD
### Theory → Hands-on → Interview Questions

---

## README

**Total sections:** 10
**Your real experience:** Nginx on EC2 (dnf module, systemd, static inventory)
**Target level:** Mid-level to Senior DevOps/Cloud Engineer

### Priority sections:
| Section | Why it matters |
|---|---|
| Part 1 — Architecture | "How does Ansible work?" — every interview starts here |
| Part 3 — Playbooks | Core skill — write one from scratch |
| Part 4 — Modules | dnf/yum, service, copy, template — your real tools |
| Part 5 — Roles | Senior-level — shows you write reusable code |
| Part 8 — Vault | Security — never commit plaintext secrets |

### Power phrases:
- *"Ansible is agentless — uses SSH and Python on the managed node, nothing to install"*
- *"Idempotent — running the same playbook twice gives the same result"*
- *"I used dnf module + systemd handler to install and manage Nginx on RHEL EC2s"*
- *"Roles make playbooks reusable — I structure them with tasks, handlers, templates, defaults"*
- *"Vault encrypts secrets at rest — I never commit plaintext passwords to git"*

---

## 📌 TABLE OF CONTENTS

| # | Section | Key Topics |
|---|---|---|
| 1 | [Architecture](#part-1--ansible-architecture) | Control node, managed nodes, SSH, agentless, Python |
| 2 | [Inventory](#part-2--inventory) | Static INI/YAML, groups, host_vars, dynamic inventory |
| 3 | [Playbooks](#part-3--playbooks) | Plays, tasks, handlers, notify, variables, tags |
| 4 | [Modules](#part-4--modules) | package, copy, template, service, file, user, shell, command |
| 5 | [Roles](#part-5--roles) | Structure, defaults, tasks, handlers, templates, reuse |
| 6 | [Variables and Precedence](#part-6--variables-and-precedence) | 22 levels, group_vars, host_vars, facts, register |
| 7 | [Conditionals Loops Error Handling](#part-7--conditionals-loops-and-error-handling) | when, loop, with_items, ignore_errors, block/rescue |
| 8 | [Ansible Vault](#part-8--ansible-vault) | Encrypt secrets, vault-id, inline, CI/CD integration |
| 9 | [Dynamic Inventory with AWS EC2](#part-9--dynamic-inventory-with-aws-ec2) | aws_ec2 plugin, tags, filters, keyed_groups |
| 10 | [Ansible in CI/CD](#part-10--ansible-in-cicd-pipelines) | GitHub Actions, Jenkins, best practices |
| — | [Interview Questions](#interview-questions) | 20 Q&A — basic to senior |
| — | [Quick Reference](#quick-reference) | Commands cheatsheet, project structure |

---

## PART 1 — ANSIBLE ARCHITECTURE

### How Ansible Works

```
Ansible = agentless configuration management + automation tool
  Push-based: control node PUSHES tasks to managed nodes
  No agent: nothing installed on managed nodes permanently
  Uses SSH (Linux) or WinRM (Windows) for transport
  Uses Python on managed nodes to execute modules

Architecture:

  ┌─────────────────────────────────────┐
  │         CONTROL NODE                │
  │  (your laptop, CI server, bastion)  │
  │                                     │
  │  ansible / ansible-playbook CLI     │
  │  Inventory (hosts file)             │
  │  Playbooks (.yml files)             │
  │  Roles / Modules / Plugins          │
  └──────────────┬──────────────────────┘
                 │
        SSH / WinRM (port 22 / 5985)
                 │
    ┌────────────┼────────────────┐
    ▼            ▼                ▼
  ┌──────┐    ┌──────┐        ┌──────┐
  │ EC2  │    │ EC2  │        │ EC2  │
  │node-1│    │node-2│        │node-3│
  │      │    │      │        │      │
  │Python│    │Python│        │Python│
  └──────┘    └──────┘        └──────┘
  Managed Nodes (only need SSH + Python)
```

### Agentless — Why It Matters

```
Chef / Puppet: require agent installed and running on every node
  Agent must be kept updated
  Agent has outbound connection to master
  Extra attack surface

Ansible: NO agent on managed nodes
  Requirements: SSH access + Python 2.7+ or 3.x (usually pre-installed)
  How it works:
    1. Ansible copies small Python script (module) to managed node via SSH
    2. Executes it remotely
    3. Captures output (JSON)
    4. Deletes temporary script
    5. Reports result to control node

Benefits:
  Zero agent management overhead
  Works immediately on any Linux machine
  Lower security attack surface
  Works behind NAT (SSH, not inbound connection)
```

### Idempotency — Core Concept

```
Idempotent: running the same operation multiple times = same result
  First run:   installs Nginx (makes a change)
  Second run:  Nginx already installed → does nothing (no change)
  Third run:   same result — no change

Why it matters:
  Safe to run playbooks repeatedly (in CI/CD, cron)
  Run on 100 nodes — only changes what needs changing
  Self-healing: run playbook on drifted node → restores correct state

Non-idempotent example (avoid):
  - name: Add line to config
    shell: echo "setting=value" >> /etc/app.conf
  # Each run APPENDS another line → config corrupted

Idempotent example (correct):
  - name: Ensure setting in config
    lineinfile:
      path: /etc/app.conf
      line: "setting=value"
      regexp: "^setting="
  # Only adds/updates if line doesn't match
```

### Key Ansible Concepts

```
Inventory:    list of managed nodes (hosts and groups)
Playbook:     YAML file defining automation tasks
Play:         maps a group of hosts to a set of tasks
Task:         one unit of work (install package, copy file, restart service)
Module:       the actual code that does the work (apt, copy, service, etc.)
Handler:      task that runs ONLY when notified (e.g., restart Nginx)
Role:         reusable, structured collection of tasks/handlers/templates
Facts:        system info auto-gathered from managed nodes (OS, IP, RAM, etc.)
Variables:    values that can be reused and overridden

Ansible components:
  ansible:          ad-hoc commands (one-off tasks)
  ansible-playbook: run playbooks
  ansible-inventory: inspect inventory
  ansible-vault:    encrypt/decrypt secrets
  ansible-galaxy:   download/install roles from community
  ansible-doc:      documentation for any module
```

### Installation and Configuration

```bash
# Install Ansible on control node
pip install ansible                    # pip (recommended)
sudo apt install ansible               # Ubuntu/Debian
sudo dnf install ansible               # RHEL/CentOS 8+
sudo yum install ansible               # CentOS 7

# Verify
ansible --version
ansible-playbook --version

# ansible.cfg — project-level config (checked in current directory first)
[defaults]
inventory      = ./inventory           # default inventory file
remote_user    = ec2-user              # SSH user for managed nodes
private_key_file = ~/.ssh/my-key.pem  # SSH private key
host_key_checking = False             # disable SSH host key check (dev only)
retry_files_enabled = False           # don't create .retry files
stdout_callback = yaml                # prettier output
forks          = 10                   # parallel connections (default 5)
timeout        = 30                   # SSH connection timeout

[privilege_escalation]
become         = True                 # use sudo by default
become_method  = sudo
become_user    = root

[ssh_connection]
pipelining     = True                 # faster (reduces SSH connections)
ssh_args       = -o ControlMaster=auto -o ControlPersist=60s  # connection reuse
```

---

## PART 2 — INVENTORY

### Static Inventory (INI format)

```ini
# inventory/hosts (INI format)

# Ungrouped hosts
web1.example.com
192.168.1.10

# Group: webservers
[webservers]
web1.example.com
web2.example.com ansible_user=ubuntu          # override SSH user
web3 ansible_host=10.0.0.3 ansible_port=2222  # custom IP and port

# Group: dbservers
[dbservers]
db1.example.com
db2.example.com

# Group: appservers
[appservers]
app1.example.com ansible_ssh_private_key_file=~/.ssh/app-key.pem

# Parent group (group of groups)
[production:children]
webservers
dbservers
appservers

# Variables for entire group
[webservers:vars]
http_port=80
nginx_version=1.24

# All hosts (built-in group)
[all:vars]
ansible_python_interpreter=/usr/bin/python3
```

### Static Inventory (YAML format — preferred)

```yaml
# inventory/hosts.yml
all:
  vars:
    ansible_user: ec2-user
    ansible_python_interpreter: /usr/bin/python3

  children:
    webservers:
      hosts:
        web1.example.com:
          ansible_host: 10.0.0.10
        web2.example.com:
          ansible_host: 10.0.0.11
      vars:
        http_port: 80
        nginx_version: "1.24"

    dbservers:
      hosts:
        db1.example.com:
          ansible_host: 10.0.0.20
          ansible_port: 5432
        db2.example.com:
          ansible_host: 10.0.0.21

    production:
      children:
        webservers:
        dbservers:

    # Your real inventory (from resume)
    rhel_servers:
      hosts:
        ec2-18-234-12-45.compute-1.amazonaws.com:
          ansible_user: ec2-user
          ansible_ssh_private_key_file: ~/.ssh/judicial-key.pem
        ec2-54-123-45-67.compute-1.amazonaws.com:
          ansible_user: ec2-user
          ansible_ssh_private_key_file: ~/.ssh/judicial-key.pem
      vars:
        ansible_python_interpreter: /usr/bin/python3
```

### Host and Group Variables Files

```
# Directory structure for variables:
inventory/
├── hosts.yml              ← inventory file
├── group_vars/
│   ├── all.yml            ← applies to ALL hosts
│   ├── webservers.yml     ← applies to webservers group
│   └── production/        ← can be a directory
│       ├── vars.yml       ← regular vars
│       └── vault.yml      ← encrypted vars
└── host_vars/
    ├── web1.example.com.yml   ← applies to specific host
    └── db1.example.com.yml
```

```yaml
# inventory/group_vars/all.yml
ansible_user: ec2-user
ansible_python_interpreter: /usr/bin/python3
environment: production
log_dir: /var/log/app

# inventory/group_vars/webservers.yml
http_port: 80
https_port: 443
nginx_worker_processes: auto
nginx_worker_connections: 1024

# inventory/host_vars/web1.example.com.yml
nginx_server_name: web1.judicialsolutions.in
server_id: web1
backup_primary: true      # only web1 is backup primary
```

### Inventory Commands

```bash
# List all hosts
ansible-inventory -i inventory/hosts.yml --list

# Graph view of groups and hosts
ansible-inventory -i inventory/hosts.yml --graph

# Show variables for specific host
ansible-inventory -i inventory/hosts.yml --host web1.example.com

# Test connectivity to all hosts
ansible all -i inventory/hosts.yml -m ping

# Test specific group
ansible webservers -i inventory/hosts.yml -m ping

# Ad-hoc: run command on all hosts
ansible all -i inventory/ -a "uptime"
ansible webservers -i inventory/ -a "systemctl status nginx"
```

---

## PART 3 — PLAYBOOKS

### Playbook Structure

```yaml
# site.yml — top-level playbook
---
# Play 1: Configure web servers
- name: Configure Nginx web servers          # play name
  hosts: webservers                          # which inventory group
  become: true                               # use sudo (privilege escalation)
  gather_facts: true                         # collect system facts (default: true)

  vars:                                      # play-level variables
    app_port: 8080
    app_name: judicial-api

  vars_files:                               # load vars from file
    - vars/common.yml
    - vars/nginx.yml

  pre_tasks:                                # run BEFORE roles
    - name: Update package cache
      ansible.builtin.dnf:
        update_cache: true
      changed_when: false                   # don't count cache update as change

  roles:                                    # apply roles in order
    - common
    - nginx
    - app

  tasks:                                    # tasks after roles
    - name: Verify nginx is responding
      ansible.builtin.uri:
        url: "http://localhost:{{ app_port }}/health"
        status_code: 200

  post_tasks:                               # run AFTER roles and tasks
    - name: Send deployment notification
      ansible.builtin.debug:
        msg: "Nginx deployed successfully on {{ inventory_hostname }}"

  handlers:                                # run when notified
    - name: reload nginx
      ansible.builtin.service:
        name: nginx
        state: reloaded

# Play 2: Configure database servers (in same playbook)
- name: Configure database servers
  hosts: dbservers
  become: true
  roles:
    - postgres
```

### Tasks — The Building Blocks

```yaml
tasks:
  # Basic task
  - name: Install nginx                     # human-readable name (required)
    ansible.builtin.dnf:                    # fully qualified module name (FQCN)
      name: nginx
      state: present                        # present/absent/latest

  # Task with multiple options
  - name: Create application directory
    ansible.builtin.file:
      path: /app/judicial
      state: directory
      owner: nginx
      group: nginx
      mode: '0755'

  # Task with register (capture output)
  - name: Check nginx status
    ansible.builtin.command:
      cmd: systemctl is-active nginx
    register: nginx_status                  # save output to variable
    ignore_errors: true                     # don't fail if nginx is inactive

  - name: Show nginx status
    ansible.builtin.debug:
      msg: "Nginx is {{ nginx_status.stdout }}"

  # Task with notify (trigger handler)
  - name: Copy nginx config
    ansible.builtin.template:
      src: nginx.conf.j2
      dest: /etc/nginx/nginx.conf
      owner: root
      group: root
      mode: '0644'
    notify: reload nginx                    # triggers handler if config changed

  # Task with tags (run selectively)
  - name: Install application packages
    ansible.builtin.dnf:
      name: "{{ item }}"
      state: present
    loop:
      - python3
      - python3-pip
      - git
    tags:
      - packages
      - install

  # Task only for specific OS
  - name: Install nginx (RHEL)
    ansible.builtin.dnf:
      name: nginx
      state: present
    when: ansible_os_family == "RedHat"

  - name: Install nginx (Debian)
    ansible.builtin.apt:
      name: nginx
      state: present
    when: ansible_os_family == "Debian"
```

### Handlers — Event-Driven Tasks

```yaml
# Handlers run ONCE at end of play if notified
# Even if notified 10 times → runs once
# Order: runs in the ORDER DEFINED in handlers section

handlers:
  - name: restart nginx
    ansible.builtin.service:
      name: nginx
      state: restarted

  - name: reload nginx                      # cheaper than restart (no downtime)
    ansible.builtin.service:
      name: nginx
      state: reloaded

  - name: restart application
    ansible.builtin.systemd:
      name: judicial-api
      state: restarted
      daemon_reload: true                   # reload systemd daemon first

tasks:
  - name: Update nginx config
    ansible.builtin.template:
      src: nginx.conf.j2
      dest: /etc/nginx/nginx.conf
    notify:
      - reload nginx                        # notify handler

  - name: Update SSL certificate
    ansible.builtin.copy:
      src: cert.pem
      dest: /etc/nginx/ssl/cert.pem
    notify:
      - reload nginx                        # same handler — only runs once!

  # Force handlers to run immediately (not wait for end of play)
  - name: Force all notified handlers now
    ansible.builtin.meta: flush_handlers
```

### Running Playbooks

```bash
# Basic run
ansible-playbook -i inventory/ site.yml

# Dry run (check mode) — shows what WOULD change, no changes made
ansible-playbook -i inventory/ site.yml --check

# Diff mode — shows exact file changes
ansible-playbook -i inventory/ site.yml --diff
ansible-playbook -i inventory/ site.yml --check --diff  # both together

# Limit to specific host or group
ansible-playbook -i inventory/ site.yml --limit webservers
ansible-playbook -i inventory/ site.yml --limit web1.example.com
ansible-playbook -i inventory/ site.yml --limit "webservers:!web1"  # exclude web1

# Run only specific tags
ansible-playbook -i inventory/ site.yml --tags packages
ansible-playbook -i inventory/ site.yml --tags "packages,config"
ansible-playbook -i inventory/ site.yml --skip-tags deploy

# Verbose output (more detail)
ansible-playbook -i inventory/ site.yml -v    # basic verbose
ansible-playbook -i inventory/ site.yml -vv   # more verbose
ansible-playbook -i inventory/ site.yml -vvv  # SSH debug level

# Pass extra variables at runtime
ansible-playbook -i inventory/ site.yml \
  --extra-vars "nginx_version=1.24 env=staging"
# OR from file:
ansible-playbook -i inventory/ site.yml \
  --extra-vars "@extra_vars.yml"

# Ask for sudo password (if not using key-based sudo)
ansible-playbook -i inventory/ site.yml --ask-become-pass

# Ask for vault password
ansible-playbook -i inventory/ site.yml --ask-vault-pass
```

---

## PART 4 — MODULES

### Package Management

```yaml
# dnf module (RHEL 8+, CentOS 8+, Fedora) — YOUR REAL EXPERIENCE
- name: Install nginx
  ansible.builtin.dnf:
    name: nginx
    state: present            # present = install if not present

- name: Install specific version
  ansible.builtin.dnf:
    name: nginx-1.24.0
    state: present

- name: Install multiple packages
  ansible.builtin.dnf:
    name:
      - nginx
      - python3
      - python3-pip
      - git
    state: present

- name: Remove package
  ansible.builtin.dnf:
    name: httpd
    state: absent

- name: Update all packages
  ansible.builtin.dnf:
    name: "*"
    state: latest

- name: Install from local RPM
  ansible.builtin.dnf:
    name: /tmp/mypackage-1.0.rpm
    state: present

# yum module (RHEL 7, CentOS 7)
- name: Install nginx (RHEL 7)
  ansible.builtin.yum:
    name: nginx
    state: present

# apt module (Ubuntu/Debian)
- name: Update apt cache and install nginx
  ansible.builtin.apt:
    name: nginx
    state: present
    update_cache: true          # apt-get update first
    cache_valid_time: 3600      # skip update if cache < 1 hour old

# package module (OS-agnostic — auto-detects dnf/apt/yum)
- name: Install nginx (any OS)
  ansible.builtin.package:
    name: nginx
    state: present
```

### Service Management — Your Real Experience

```yaml
# service/systemd modules — what you used for Nginx
- name: Start and enable nginx                # start + enable on boot
  ansible.builtin.service:
    name: nginx
    state: started                            # started/stopped/restarted/reloaded
    enabled: true                             # start on boot

- name: Stop and disable nginx
  ansible.builtin.service:
    name: nginx
    state: stopped
    enabled: false

- name: Reload nginx (no downtime)
  ansible.builtin.service:
    name: nginx
    state: reloaded                           # sends SIGHUP (no connection drop)

- name: Restart nginx (brief downtime)
  ansible.builtin.service:
    name: nginx
    state: restarted

# systemd module (more features than service)
- name: Start nginx with systemd
  ansible.builtin.systemd:
    name: nginx
    state: started
    enabled: true
    daemon_reload: true                       # reload unit files first

- name: Create and enable custom service
  ansible.builtin.systemd:
    name: judicial-api
    state: started
    enabled: true
    daemon_reload: true
```

### File Operations

```yaml
# file module — create dirs, set permissions, symlinks
- name: Create directory
  ansible.builtin.file:
    path: /app/judicial/logs
    state: directory                          # directory/file/link/absent/touch
    owner: nginx
    group: nginx
    mode: '0755'
    recurse: true                             # apply to all contents

- name: Create symbolic link
  ansible.builtin.file:
    src: /etc/nginx/sites-available/judicial
    dest: /etc/nginx/sites-enabled/judicial
    state: link

- name: Delete file or directory
  ansible.builtin.file:
    path: /tmp/old-config.conf
    state: absent

# copy module — copy files from control node to managed node
- name: Copy nginx config
  ansible.builtin.copy:
    src: files/nginx.conf                     # relative to playbook or role
    dest: /etc/nginx/nginx.conf
    owner: root
    group: root
    mode: '0644'
    backup: true                              # backup existing file

- name: Copy inline content to file
  ansible.builtin.copy:
    dest: /etc/app/settings.conf
    content: |
      server.port=8080
      log.level=info
    owner: app
    mode: '0640'

# template module — Jinja2 templating (vars replaced before copying)
- name: Deploy nginx config from template
  ansible.builtin.template:
    src: templates/nginx.conf.j2             # Jinja2 template
    dest: /etc/nginx/nginx.conf
    owner: root
    group: root
    mode: '0644'
    validate: nginx -t -c %s                  # validate before deploying
  notify: reload nginx

# fetch module — copy from managed node to control node
- name: Fetch nginx logs for analysis
  ansible.builtin.fetch:
    src: /var/log/nginx/error.log
    dest: ./logs/{{ inventory_hostname }}-nginx-error.log
    flat: true                                # no directory structure
```

### User and Group Management

```yaml
- name: Create application user
  ansible.builtin.user:
    name: appuser
    uid: 1001
    group: appgroup
    groups:
      - nginx
      - docker
    shell: /bin/bash
    home: /home/appuser
    create_home: true
    system: false                             # not a system user
    comment: "Application Service Account"
    password: "{{ user_password | password_hash('sha512') }}"

- name: Create group
  ansible.builtin.group:
    name: appgroup
    gid: 1001
    state: present

- name: Add SSH authorized key
  ansible.posix.authorized_key:
    user: ec2-user
    state: present
    key: "{{ lookup('file', '~/.ssh/id_rsa.pub') }}"
```

### Command Execution

```yaml
# command module — runs command, NO shell features ($var, pipes, &&)
- name: Check nginx syntax
  ansible.builtin.command:
    cmd: nginx -t
  changed_when: false               # command doesn't change state

# Use creates/removes for idempotency
- name: Initialize database (only if not done)
  ansible.builtin.command:
    cmd: /app/bin/init-db.sh
    creates: /app/.db-initialized    # skip if this file exists
    removes: /app/.setup-needed      # skip if this file doesn't exist

# shell module — runs via /bin/sh, supports pipes, &&, redirects, $vars
- name: Get nginx version
  ansible.builtin.shell:
    cmd: nginx -v 2>&1 | awk '{print $3}'
  register: nginx_ver
  changed_when: false

- name: Show version
  ansible.builtin.debug:
    msg: "Nginx version: {{ nginx_ver.stdout }}"

# RULE: prefer command over shell (safer, no shell injection)
# Use shell only when you need: pipes | redirects > env vars $ glob * 

# raw module — runs command without Python (for bootstrapping)
- name: Install Python on bare node
  ansible.builtin.raw: dnf install -y python3
  changed_when: true
```

### Networking and URI

```yaml
# uri module — HTTP requests
- name: Check API health
  ansible.builtin.uri:
    url: "http://localhost:8080/health"
    method: GET
    status_code: 200
    return_content: true
  register: health_response

- name: Call API endpoint
  ansible.builtin.uri:
    url: "https://api.example.com/deploy"
    method: POST
    headers:
      Authorization: "Bearer {{ api_token }}"
      Content-Type: "application/json"
    body_format: json
    body:
      version: "{{ app_version }}"
      environment: "production"
    status_code: [200, 201]

# wait_for module — wait for condition
- name: Wait for nginx to start
  ansible.builtin.wait_for:
    port: 80
    host: localhost
    delay: 5                          # wait 5s before first check
    timeout: 60                       # fail after 60s

- name: Wait for file to exist
  ansible.builtin.wait_for:
    path: /app/.ready
    state: present
    timeout: 120
```

---

## PART 5 — ROLES

### Why Roles?

```
Problem without roles:
  site.yml: 800 lines, everything mixed together
  Hard to reuse for another project
  Hard to test independently
  Hard to share with team

With roles:
  nginx role: self-contained, reusable
  Call it in any playbook: - role: nginx
  Share on Ansible Galaxy
  Test independently
  Override defaults for each environment
```

### Role Directory Structure

```
roles/
└── nginx/                    ← role name
    ├── tasks/
    │   └── main.yml          ← main task list (auto-loaded)
    ├── handlers/
    │   └── main.yml          ← handlers (auto-loaded)
    ├── templates/
    │   └── nginx.conf.j2     ← Jinja2 templates
    ├── files/
    │   └── mime.types        ← static files to copy
    ├── vars/
    │   └── main.yml          ← role variables (high priority, hard to override)
    ├── defaults/
    │   └── main.yml          ← default values (lowest priority, easy to override)
    ├── meta/
    │   └── main.yml          ← role metadata, dependencies
    └── README.md             ← documentation
```

### Create Role from Scratch

```bash
# Create role structure automatically
ansible-galaxy role init roles/nginx
ansible-galaxy role init roles/postgresql
ansible-galaxy role init roles/judicial-api
```

### Complete Nginx Role Example — Your Real Experience

```yaml
# roles/nginx/defaults/main.yml
---
# Default values (easily overridden by playbook/inventory vars)
nginx_user: nginx
nginx_group: nginx
nginx_worker_processes: auto
nginx_worker_connections: 1024
nginx_keepalive_timeout: 65
nginx_http_port: 80
nginx_https_port: 443
nginx_server_name: "_"
nginx_access_log: /var/log/nginx/access.log
nginx_error_log: /var/log/nginx/error.log
nginx_log_level: warn
nginx_document_root: /var/www/html
nginx_app_port: 8080
```

```yaml
# roles/nginx/tasks/main.yml
---
- name: Install nginx
  ansible.builtin.dnf:
    name: nginx
    state: present
  tags: packages

- name: Create nginx directories
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    owner: "{{ nginx_user }}"
    group: "{{ nginx_group }}"
    mode: '0755'
  loop:
    - /etc/nginx/conf.d
    - /var/log/nginx
    - "{{ nginx_document_root }}"

- name: Deploy nginx main config
  ansible.builtin.template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
    owner: root
    group: root
    mode: '0644'
    validate: nginx -t -c %s          # test config before replacing
  notify: reload nginx
  tags: config

- name: Deploy virtual host config
  ansible.builtin.template:
    src: vhost.conf.j2
    dest: /etc/nginx/conf.d/{{ nginx_server_name }}.conf
    mode: '0644'
    validate: nginx -t -c %s
  notify: reload nginx
  tags: config

- name: Ensure nginx is started and enabled
  ansible.builtin.systemd:
    name: nginx
    state: started
    enabled: true
    daemon_reload: true
  tags: service

- name: Verify nginx is responding
  ansible.builtin.uri:
    url: "http://localhost:{{ nginx_http_port }}"
    status_code: [200, 301, 302]
  retries: 3
  delay: 5
  tags: verify
```

```yaml
# roles/nginx/handlers/main.yml
---
- name: reload nginx
  ansible.builtin.systemd:
    name: nginx
    state: reloaded

- name: restart nginx
  ansible.builtin.systemd:
    name: nginx
    state: restarted
    daemon_reload: true
```

```jinja2
{# roles/nginx/templates/nginx.conf.j2 #}
user {{ nginx_user }};
worker_processes {{ nginx_worker_processes }};
error_log {{ nginx_error_log }} {{ nginx_log_level }};
pid /run/nginx.pid;

events {
    worker_connections {{ nginx_worker_connections }};
}

http {
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log {{ nginx_access_log }} main;

    sendfile        on;
    tcp_nopush      on;
    keepalive_timeout {{ nginx_keepalive_timeout }};

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    include /etc/nginx/conf.d/*.conf;
}
```

```jinja2
{# roles/nginx/templates/vhost.conf.j2 #}
server {
    listen {{ nginx_http_port }};
    server_name {{ nginx_server_name }};

    root {{ nginx_document_root }};
    index index.html index.htm;

    location / {
        try_files $uri $uri/ =404;
    }

    location /api {
        proxy_pass http://127.0.0.1:{{ nginx_app_port }};
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 5s;
        proxy_read_timeout 30s;
    }

    error_log {{ nginx_error_log }};
    access_log {{ nginx_access_log }};
}
```

```yaml
# roles/nginx/meta/main.yml
---
galaxy_info:
  author: aditya
  description: Configure Nginx web server on RHEL
  license: MIT
  min_ansible_version: "2.9"
  platforms:
    - name: EL                          # Enterprise Linux
      versions:
        - 8
        - 9

dependencies:
  - role: common                        # nginx depends on common role
```

### Using Roles in a Playbook

```yaml
# site.yml
---
- name: Configure web servers
  hosts: webservers
  become: true

  roles:
    # Simple role reference
    - common

    # Role with custom variables (override defaults)
    - role: nginx
      vars:
        nginx_http_port: 80
        nginx_https_port: 443
        nginx_server_name: judicialsolutions.in
        nginx_app_port: 8080

    # Only run specific tags
    - role: nginx
      tags: [nginx, webserver]

  tasks:
    - name: Verify setup
      ansible.builtin.debug:
        msg: "{{ inventory_hostname }} configured successfully"
```

### Installing Roles from Ansible Galaxy

```bash
# Install community role
ansible-galaxy role install geerlingguy.nginx
ansible-galaxy role install geerlingguy.postgresql

# Install from requirements file
ansible-galaxy role install -r requirements.yml

# requirements.yml
roles:
  - name: geerlingguy.nginx
    version: "3.2.0"
  - name: geerlingguy.postgresql
    version: "3.4.0"
  - src: https://github.com/myorg/ansible-role-app
    name: judicial-app

# List installed roles
ansible-galaxy role list

# Remove role
ansible-galaxy role remove geerlingguy.nginx
```

---

## PART 6 — VARIABLES AND PRECEDENCE

### Variable Precedence (22 levels — lower = lower priority)

```
LOWEST PRIORITY (easiest to override):
1.  command line role defaults
2.  role defaults (defaults/main.yml)          ← most commonly used
3.  inventory file/script group vars
4.  inventory group_vars/all
5.  playbook group_vars/all
6.  inventory group_vars/*
7.  playbook group_vars/*
8.  inventory file/script host vars
9.  inventory host_vars/*
10. playbook host_vars/*
11. host facts / cached set_facts
12. play vars
13. play vars_prompt
14. play vars_files
15. role vars (vars/main.yml)
16. block vars (only for tasks in block)
17. task vars (only for the task)
18. include_vars
19. set_facts / registered vars
20. role (and include_role) params
21. include params
22. extra vars (-e on command line)      ← HIGHEST PRIORITY (always wins)

Rule: more specific = higher priority
  host_vars > group_vars > defaults
  -e > everything else
```

### Variable Types and Usage

```yaml
# Play variables (medium priority)
- name: Deploy application
  hosts: appservers
  vars:
    app_version: "1.2.3"
    app_port: 8080
    db_host: "{{ groups['dbservers'][0] }}"  # reference another host

# Variables from files
  vars_files:
    - vars/common.yml
    - vars/{{ ansible_os_family }}.yml      # OS-specific vars file

# Prompt user for variable (interactive)
  vars_prompt:
    - name: app_version
      prompt: "Which version to deploy?"
      private: false
      default: "1.0.0"

# Register task output as variable
tasks:
  - name: Get current version
    ansible.builtin.command:
      cmd: cat /app/VERSION
    register: current_version               # captured output

  - name: Show version
    ansible.builtin.debug:
      msg: "Current: {{ current_version.stdout }}, New: {{ app_version }}"

  # register object properties:
  # .stdout         - standard output (string)
  # .stderr         - standard error (string)
  # .rc             - return code (int)
  # .stdout_lines   - stdout as list of lines
  # .changed        - did task change anything (bool)
  # .failed         - did task fail (bool)

# set_fact — set variables dynamically
  - name: Set derived variable
    ansible.builtin.set_fact:
      deploy_timestamp: "{{ ansible_date_time.iso8601 }}"
      should_restart: "{{ current_version.stdout != app_version }}"
```

### Ansible Facts

```yaml
# Facts are automatically gathered about each managed node
# Access via ansible_* variables

- name: Show system facts
  ansible.builtin.debug:
    msg:
      - "Hostname: {{ ansible_hostname }}"
      - "FQDN: {{ ansible_fqdn }}"
      - "OS family: {{ ansible_os_family }}"
      - "Distribution: {{ ansible_distribution }}"
      - "Version: {{ ansible_distribution_version }}"
      - "Architecture: {{ ansible_architecture }}"
      - "Kernel: {{ ansible_kernel }}"
      - "Total RAM: {{ ansible_memtotal_mb }} MB"
      - "CPU cores: {{ ansible_processor_vcpus }}"
      - "Default IPv4: {{ ansible_default_ipv4.address }}"
      - "Python: {{ ansible_python_version }}"

# Common facts:
# ansible_hostname            → short hostname
# ansible_fqdn                → fully qualified domain name
# ansible_os_family           → RedHat, Debian, Windows
# ansible_distribution        → CentOS, Ubuntu, Amazon
# ansible_distribution_version→ 8.5, 22.04
# ansible_architecture        → x86_64, aarch64
# ansible_memtotal_mb         → total RAM in MB
# ansible_processor_vcpus     → number of vCPUs
# ansible_default_ipv4.address→ primary IP address
# ansible_all_ipv4_addresses  → list of all IPs
# ansible_env                 → environment variables dict
# ansible_user_id             → user running ansible
# ansible_date_time           → current date/time info

# Disable fact gathering (speed up when facts not needed)
- name: Quick play
  hosts: all
  gather_facts: false
  tasks:
    - name: Just restart a service
      ansible.builtin.service:
        name: nginx
        state: restarted

# Gather specific subset of facts
- name: Get network facts only
  hosts: all
  gather_facts: true
  gather_subset:
    - network
    - hardware
```

### Jinja2 Templating in Variables

```yaml
# String manipulation
app_url: "https://{{ ansible_hostname }}.example.com"
log_file: "/var/log/{{ app_name }}/{{ ansible_date_time.date }}.log"

# Filters (Jinja2 + Ansible filters)
app_name_upper: "{{ app_name | upper }}"          # JUDICIAL-API
app_name_title: "{{ app_name | title }}"          # Judicial-Api
version_int: "{{ app_version | int }}"            # convert to int
default_val: "{{ my_var | default('fallback') }}" # use default if undefined
items_joined: "{{ my_list | join(',') }}"         # join list with comma
dict_keys: "{{ my_dict | dict2items }}"           # convert dict to list

# Boolean
is_prod: "{{ environment == 'production' }}"
is_rhel: "{{ ansible_os_family == 'RedHat' }}"

# Conditional value
nginx_workers: "{{ ansible_processor_vcpus if ansible_processor_vcpus > 1 else 1 }}"

# List operations
first_db: "{{ groups['dbservers'] | first }}"
all_ips: "{{ ansible_all_ipv4_addresses | join(' ') }}"
```

---

## PART 7 — CONDITIONALS, LOOPS, AND ERROR HANDLING

### Conditionals (when)

```yaml
tasks:
  # Simple condition
  - name: Install nginx on RHEL
    ansible.builtin.dnf:
      name: nginx
      state: present
    when: ansible_os_family == "RedHat"

  - name: Install nginx on Debian
    ansible.builtin.apt:
      name: nginx
      state: present
    when: ansible_os_family == "Debian"

  # Multiple conditions (AND)
  - name: Configure production settings
    ansible.builtin.template:
      src: prod.conf.j2
      dest: /etc/app/config.conf
    when:
      - environment == "production"
      - ansible_distribution_version is version('8', '>=')

  # OR condition
  - name: Install on CentOS or RHEL
    ansible.builtin.dnf:
      name: nginx
    when: ansible_distribution in ["CentOS", "RedHat", "Rocky"]

  # Condition based on registered var
  - name: Check if app is running
    ansible.builtin.command:
      cmd: pgrep -x judicial-api
    register: app_check
    ignore_errors: true
    changed_when: false

  - name: Start app only if not running
    ansible.builtin.service:
      name: judicial-api
      state: started
    when: app_check.rc != 0           # rc=0 means running, rc=1 means not found

  # Condition based on variable truth
  - name: Enable SSL
    ansible.builtin.include_tasks: ssl.yml
    when: enable_ssl | bool           # convert to boolean
```

### Loops

```yaml
tasks:
  # Loop over list (modern syntax)
  - name: Install required packages
    ansible.builtin.dnf:
      name: "{{ item }}"
      state: present
    loop:
      - nginx
      - python3
      - python3-pip
      - git
      - curl

  # Loop over list of dicts
  - name: Create multiple directories
    ansible.builtin.file:
      path: "{{ item.path }}"
      state: directory
      owner: "{{ item.owner }}"
      mode: "{{ item.mode }}"
    loop:
      - { path: /app/logs, owner: nginx, mode: '0755' }
      - { path: /app/data, owner: appuser, mode: '0700' }
      - { path: /app/config, owner: root, mode: '0644' }

  # Loop with index
  - name: Show items with index
    ansible.builtin.debug:
      msg: "Item {{ my_idx }}: {{ item }}"
    loop: "{{ my_list }}"
    loop_control:
      index_var: my_idx
      loop_var: item                  # rename loop variable (default: item)
      label: "{{ item }}"            # what to show in output

  # Loop over dict
  - name: Set environment variables
    ansible.builtin.lineinfile:
      path: /etc/environment
      line: "{{ item.key }}={{ item.value }}"
      regexp: "^{{ item.key }}="
    loop: "{{ env_vars | dict2items }}"
    vars:
      env_vars:
        APP_ENV: production
        APP_PORT: "8080"
        LOG_LEVEL: info

  # until loop (retry until condition met)
  - name: Wait for app to become healthy
    ansible.builtin.uri:
      url: http://localhost:8080/health
      status_code: 200
    register: health
    until: health.status == 200
    retries: 10                       # try up to 10 times
    delay: 6                          # wait 6 seconds between tries
```

### Error Handling

```yaml
tasks:
  # Ignore errors (continue playbook even if task fails)
  - name: Stop app (may not be running)
    ansible.builtin.service:
      name: judicial-api
      state: stopped
    ignore_errors: true               # don't fail play if service doesn't exist

  # Fail on specific conditions
  - name: Check disk space
    ansible.builtin.command:
      cmd: df -h /
    register: disk_usage
    changed_when: false

  - name: Fail if disk is almost full
    ansible.builtin.fail:
      msg: "Disk usage critical: {{ disk_usage.stdout }}"
    when: disk_usage.stdout | regex_search('9[0-9]%')

  # Block / Rescue / Always (try/catch/finally)
  - name: Deploy application
    block:
      - name: Deploy new version
        ansible.builtin.copy:
          src: app-v2.tar.gz
          dest: /app/releases/

      - name: Extract new version
        ansible.builtin.unarchive:
          src: /app/releases/app-v2.tar.gz
          dest: /app/current/
          remote_src: true

      - name: Restart service
        ansible.builtin.service:
          name: judicial-api
          state: restarted

    rescue:                           # runs if ANYTHING in block fails
      - name: Rollback to previous version
        ansible.builtin.file:
          src: /app/releases/app-v1.tar.gz
          dest: /app/current/
          state: link

      - name: Restart with old version
        ansible.builtin.service:
          name: judicial-api
          state: restarted

      - name: Send failure notification
        ansible.builtin.debug:
          msg: "Deployment failed! Rolled back to previous version."

    always:                           # always runs regardless of success/failure
      - name: Cleanup temp files
        ansible.builtin.file:
          path: /tmp/deploy/
          state: absent

  # changed_when / failed_when — control when task reports changes/failures
  - name: Get service status
    ansible.builtin.command:
      cmd: systemctl is-active nginx
    register: nginx_status
    changed_when: false               # command never counts as a change
    failed_when: false                # never count as failure (handle manually)

  - name: Assert nginx is running
    ansible.builtin.assert:
      that:
        - nginx_status.rc == 0
      fail_msg: "Nginx is not running! Status: {{ nginx_status.stdout }}"
      success_msg: "Nginx is running."
```

---

## PART 8 — ANSIBLE VAULT

### Why Vault?

```
Problem: passwords, API keys, certificates in plaintext YAML files
  If committed to git → secrets exposed
  If shared with team → secrets distributed insecurely

Vault: encrypt files or individual strings with AES-256
  Encrypted file committed to git → safe
  Only people with vault password can decrypt
  Ansible decrypts transparently at runtime
```

### Vault Commands

```bash
# Create new encrypted file
ansible-vault create vars/secrets.yml
# Opens editor → type content → save → file is encrypted

# Encrypt existing file
ansible-vault encrypt vars/passwords.yml

# View encrypted file
ansible-vault view vars/secrets.yml

# Edit encrypted file
ansible-vault edit vars/secrets.yml

# Decrypt file (careful — writes plaintext to disk)
ansible-vault decrypt vars/secrets.yml

# Re-encrypt with new password
ansible-vault rekey vars/secrets.yml

# Encrypt a single string (inline vault)
ansible-vault encrypt_string 'MyStr0ngP@ssword' --name 'db_password'
# Output:
# db_password: !vault |
#   $ANSIBLE_VAULT;1.1;AES256
#   34313...

# Check if file is encrypted
head -1 vars/secrets.yml
# $ANSIBLE_VAULT;1.1;AES256  ← encrypted
# ---                          ← not encrypted
```

### Using Vault in Playbooks

```yaml
# vars/secrets.yml (encrypted with ansible-vault)
# Contents (before encryption):
db_password: "MyStr0ngP@ssword"
api_key: "sk-1234567890abcdef"
ssl_cert_password: "certpassword123"

# In playbook — reference like any variable
- name: Configure database
  hosts: dbservers
  vars_files:
    - vars/common.yml
    - vars/secrets.yml             # ansible decrypts at runtime
  tasks:
    - name: Set DB password
      ansible.builtin.shell:
        cmd: "psql -c \"ALTER USER app PASSWORD '{{ db_password }}';\""
      no_log: true                 # prevent password showing in output

# Inline vault (single variable encrypted)
# group_vars/all.yml:
db_password: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  34313534313439393739303...

# Run playbook with vault
ansible-playbook site.yml --ask-vault-pass             # interactive
ansible-playbook site.yml --vault-password-file .vault_pass  # from file
ansible-playbook site.yml --vault-id prod@.vault_pass  # vault-id (multiple vaults)
```

### Vault Best Practices

```bash
# .vault_pass file (store vault password)
echo "MyVaultPassword123" > .vault_pass
chmod 600 .vault_pass

# Add to .gitignore (NEVER commit)
echo ".vault_pass" >> .gitignore

# Use environment variable instead of file
export ANSIBLE_VAULT_PASSWORD_FILE=.vault_pass
ansible-playbook site.yml             # no --vault-password-file needed

# Multiple vault IDs (different passwords per environment)
ansible-vault create --vault-id dev@dev.pass  vars/dev-secrets.yml
ansible-vault create --vault-id prod@prod.pass vars/prod-secrets.yml

ansible-playbook site.yml \
  --vault-id dev@dev.pass \
  --vault-id prod@prod.pass

# In CI/CD (GitHub Actions):
# Store vault password as GitHub Secret
# Reference as: --vault-password-file <(echo "${{ secrets.ANSIBLE_VAULT_PASS }}")

# Structure: separate encrypted files per environment
group_vars/
├── all/
│   ├── vars.yml          ← regular vars (commit to git)
│   └── vault.yml         ← encrypted secrets (safe to commit)
├── production/
│   ├── vars.yml
│   └── vault.yml         ← prod-specific encrypted secrets
└── staging/
    ├── vars.yml
    └── vault.yml
```

---

## PART 9 — DYNAMIC INVENTORY WITH AWS EC2

### Why Dynamic Inventory?

```
Static inventory problem:
  You have 50 EC2 instances
  Instances added/removed by Auto Scaling
  IPs change
  Must manually update hosts file → error-prone

Dynamic inventory:
  Queries AWS API at runtime
  Returns current list of instances
  Filter by tags, region, state
  IPs always current
  No manual maintenance
```

### AWS EC2 Plugin Setup

```bash
# Install required collection
ansible-galaxy collection install amazon.aws

# Install boto3 (AWS SDK for Python)
pip install boto3 botocore

# Configure AWS credentials (one of these methods)
export AWS_ACCESS_KEY_ID=AKIA...
export AWS_SECRET_ACCESS_KEY=...
export AWS_DEFAULT_REGION=ap-south-1

# OR use IAM role on control node (if control node is EC2)
# OR use ~/.aws/credentials file
```

```yaml
# inventory/aws_ec2.yml (plugin config file)
plugin: amazon.aws.aws_ec2

# AWS settings
regions:
  - ap-south-1
  - us-east-1

# Filters — only return specific instances
filters:
  instance-state-name: running          # only running instances
  "tag:Environment": production         # only production-tagged
  "tag:ManagedBy": ansible             # only ansible-managed

# What to use as hostname (for SSH connection)
hostnames:
  - private-ip-address                  # use private IP (inside VPC)
  # - public-ip-address                 # use public IP (if accessible)
  # - private-dns-name                  # use private DNS name
  # - dns-name                          # use public DNS name

# Group instances by tag values
keyed_groups:
  - key: tags.Role                      # group by Role tag
    prefix: role                        # e.g., role_webserver, role_database
    separator: _

  - key: tags.Environment               # group by Environment tag
    prefix: env
    separator: _                        # env_production, env_staging

  - key: instance_type                  # group by instance type
    prefix: type

  - key: placement.region               # group by region
    prefix: region

# Add tag values as host variables
compose:
  ansible_host: private_ip_address      # use private IP for SSH
  ansible_user: ec2-user                # SSH user
  instance_name: tags.Name              # make Name tag available as variable

# Additional host variables
vars:
  ansible_ssh_private_key_file: ~/.ssh/judicial-key.pem
  ansible_python_interpreter: /usr/bin/python3
```

```bash
# Test dynamic inventory
ansible-inventory -i inventory/aws_ec2.yml --list
ansible-inventory -i inventory/aws_ec2.yml --graph

# Example output:
# @all:
#   @role_webserver:
#     ec2-54-123-45-67.compute-1.amazonaws.com
#     ec2-54-123-45-68.compute-1.amazonaws.com
#   @role_database:
#     ec2-54-123-45-70.compute-1.amazonaws.com
#   @env_production:
#     ec2-54-123-45-67.compute-1.amazonaws.com
#     ec2-54-123-45-70.compute-1.amazonaws.com

# Run playbook with dynamic inventory
ansible-playbook -i inventory/aws_ec2.yml site.yml
ansible-playbook -i inventory/aws_ec2.yml site.yml \
  --limit role_webserver                # only webserver instances

# Test connectivity to all discovered hosts
ansible all -i inventory/aws_ec2.yml -m ping
```

### Mixed Static + Dynamic Inventory

```
# Use directory as inventory → Ansible merges all files
inventory/
├── aws_ec2.yml        ← dynamic (AWS instances)
├── static_hosts.yml   ← static (on-premise servers)
└── group_vars/
    ├── all.yml
    └── role_webserver.yml

ansible-playbook -i inventory/ site.yml
# Ansible reads all files in directory and merges them
```

### Tag Strategy for Dynamic Inventory

```
Tag every EC2 instance consistently:

Name:         judicial-api-prod-1       (human-readable name)
Environment:  production / staging / dev
Role:         webserver / database / cache / worker
ManagedBy:    ansible / terraform / manual
Application:  judicial / billing / auth
Owner:        devops-team
CostCenter:   DEVOPS-2024

Result in inventory:
  Groups: env_production, role_webserver, application_judicial
  Filter: only manage instances tagged ManagedBy=ansible
```

---

## PART 10 — ANSIBLE IN CI/CD PIPELINES

### GitHub Actions with Ansible

```yaml
# .github/workflows/deploy.yml
name: Deploy with Ansible

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        default: 'staging'
        type: choice
        options: [staging, production]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ github.event.inputs.environment || 'staging' }}

    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - name: Install Ansible and dependencies
        run: |
          pip install ansible boto3 botocore
          ansible-galaxy collection install amazon.aws
          ansible-galaxy role install -r requirements.yml

      - name: Configure AWS credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ap-south-1

      - name: Write vault password
        run: echo "${{ secrets.ANSIBLE_VAULT_PASS }}" > .vault_pass
        # Security: write to file, not to env var
        # File stays in runner (not committed)

      - name: Validate playbook (syntax check)
        run: |
          ansible-playbook \
            -i inventory/aws_ec2.yml \
            site.yml \
            --syntax-check

      - name: Run Ansible linting
        run: |
          pip install ansible-lint
          ansible-lint site.yml

      - name: Deploy with Ansible (dry run first)
        if: github.ref != 'refs/heads/main'
        run: |
          ansible-playbook \
            -i inventory/aws_ec2.yml \
            site.yml \
            --check \
            --diff \
            --vault-password-file .vault_pass \
            --extra-vars "env=${{ github.event.inputs.environment }}"

      - name: Deploy with Ansible (production)
        if: github.ref == 'refs/heads/main'
        run: |
          ansible-playbook \
            -i inventory/aws_ec2.yml \
            site.yml \
            --vault-password-file .vault_pass \
            --extra-vars "env=production" \
            --limit role_webserver \
            2>&1 | tee ansible-output.log

      - name: Cleanup vault password
        if: always()
        run: rm -f .vault_pass

      - name: Upload Ansible logs
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: ansible-logs
          path: ansible-output.log
```

### Jenkins Pipeline with Ansible

```groovy
// Jenkinsfile
pipeline {
    agent any

    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['staging', 'production'],
            description: 'Target environment'
        )
        string(
            name: 'LIMIT',
            defaultValue: 'all',
            description: 'Ansible --limit value'
        )
        booleanParam(
            name: 'DRY_RUN',
            defaultValue: true,
            description: 'Run with --check flag'
        )
    }

    environment {
        ANSIBLE_HOST_KEY_CHECKING = 'False'
        ANSIBLE_STDOUT_CALLBACK = 'yaml'
        AWS_DEFAULT_REGION = 'ap-south-1'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Setup') {
            steps {
                sh '''
                    pip install ansible boto3 botocore ansible-lint
                    ansible-galaxy collection install amazon.aws
                    ansible-galaxy role install -r requirements.yml
                '''
            }
        }

        stage('Lint') {
            steps {
                sh 'ansible-lint site.yml'
                sh 'ansible-playbook -i inventory/aws_ec2.yml site.yml --syntax-check'
            }
        }

        stage('Deploy') {
            steps {
                withCredentials([
                    string(credentialsId: 'ansible-vault-pass', variable: 'VAULT_PASS'),
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: 'aws-credentials']
                ]) {
                    sh """
                        echo "${VAULT_PASS}" > .vault_pass
                        chmod 600 .vault_pass

                        ansible-playbook \\
                            -i inventory/aws_ec2.yml \\
                            site.yml \\
                            --vault-password-file .vault_pass \\
                            --extra-vars "env=${params.ENVIRONMENT}" \\
                            --limit "${params.LIMIT}" \\
                            ${params.DRY_RUN ? '--check --diff' : ''} \\
                            2>&1 | tee ansible-output.log

                        rm -f .vault_pass
                    """
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'ansible-output.log'
                    sh 'rm -f .vault_pass'  // always clean up
                }
            }
        }
    }

    post {
        success {
            slackSend(
                color: 'good',
                message: "✅ Ansible deploy to ${params.ENVIRONMENT} succeeded"
            )
        }
        failure {
            slackSend(
                color: 'danger',
                message: "❌ Ansible deploy to ${params.ENVIRONMENT} FAILED"
            )
        }
    }
}
```

### Ansible Best Practices for CI/CD

```
1. Always syntax-check before running:
   ansible-playbook site.yml --syntax-check

2. Lint your playbooks:
   pip install ansible-lint
   ansible-lint site.yml
   # Catches: bad practices, deprecated syntax, style issues

3. Dry run on PRs, real run on merge:
   PR:   --check --diff → shows what would change
   Main: real run → applies changes

4. Pin versions:
   requirements.yml:
     collections:
       - name: amazon.aws
         version: "7.0.0"     # pin version
   Never use: version: latest (breaks unpredictably)

5. Never store secrets in plaintext:
   Use ansible-vault for all secrets
   vault_pass file in .gitignore

6. Idempotent playbooks:
   Test: run twice in CI, second run should have 0 changes

7. Limit blast radius:
   Use --limit for targeted deploys
   Never run all hosts if only changing webservers

8. Log everything:
   Pipe output to file: 2>&1 | tee deploy.log
   Archive as CI artifact
   Keep for post-mortem if deployment fails

9. Test in staging before production:
   CI pipeline: staging (auto) → production (manual approval)

10. Use tags for partial runs:
    ansible-playbook site.yml --tags config    # only config tasks
    ansible-playbook site.yml --tags packages  # only package installs
```

---

## INTERVIEW QUESTIONS

**Q1: What is Ansible and how is it different from Chef/Puppet?**

```
Ansible:
  Agentless — uses SSH, no agent installed on managed nodes
  Push-based — control node pushes tasks to managed nodes
  YAML — human-readable, low learning curve
  Stateless — no database of desired state (runs playbook each time)
  Good for: configuration management, ad-hoc tasks, orchestration

Chef/Puppet:
  Agent-based — agent installed and running on every node
  Pull-based — agents poll master for configuration
  DSL — steeper learning curve (Ruby-based)
  Stateful — agents track and enforce state continuously
  Good for: continuous enforcement, complex state management

Why Ansible is popular in DevOps:
  Works immediately on any SSH-accessible Linux machine
  No infrastructure to manage (no master server)
  YAML = developers can write playbooks without Ops background
  Can orchestrate across multiple systems (Terraform + K8s + EC2)
```

**Q2: What is idempotency and why is it important?**

```
Idempotent: running the same operation N times = same result as running once

Example:
  Non-idempotent: shell: echo "line" >> file
    Run twice: file has duplicate lines
  
  Idempotent: lineinfile: line="line" in file
    Run twice: file has the line exactly once

Why it matters:
  1. Safe to re-run: fix drift by running playbook again
  2. CI/CD: run every deployment without manual checks
  3. Self-healing: periodic runs correct configuration drift
  4. Predictable: know exactly what state nodes will be in
  5. Dry run: --check shows exactly what will change

Most Ansible modules are idempotent by design.
When using command/shell: add creates/removes or changed_when: false
```

**Q3: Walk me through your Ansible work from your resume (Nginx on EC2)**

```
"I wrote Ansible playbooks to automate Nginx installation and service
management on RHEL EC2 instances. Here's exactly what I did:

Static inventory:
  Created a hosts.yml with two RHEL EC2 instances
  Configured ansible_user: ec2-user and SSH key path

Playbook:
  Used dnf module to install nginx (RHEL package manager)
  Used file module to create /etc/nginx/conf.d/ directory
  Used template module with Jinja2 to deploy nginx.conf
  Used systemd module to start nginx and enable on boot
  Handler: notify 'reload nginx' when config changes

Why handlers:
  Template task notifies reload handler
  If config hasn't changed: handler NOT triggered (idempotent)
  If config changed: nginx reloaded (no downtime — not restarted)

Why dnf not yum:
  RHEL 8+ uses dnf (yum is symlink to dnf)
  dnf module is more correct for RHEL 8/9

Result: one playbook installs and configures Nginx consistently
across all EC2 instances, handlers ensure service reloads only
when config actually changes"
```

**Q4: What is the difference between the copy and template modules?**

```
copy module:
  Copies file exactly as-is from control node to managed node
  No variable substitution
  Use for: binary files, static configs, certs, scripts
  src: files/nginx.conf → copies exactly

template module:
  Processes file as Jinja2 template first
  Variables replaced: {{ nginx_port }} → 80
  Conditionals/loops: {% if ssl_enabled %} ... {% endif %}
  Then copies rendered file to managed node
  Use for: any config that varies by host/environment
  src: templates/nginx.conf.j2 → renders then copies

Your real use case:
  nginx.conf.j2 template with:
    worker_processes {{ ansible_processor_vcpus }}
    listen {{ nginx_http_port }}
    server_name {{ nginx_server_name }}
  
  Different hosts get different values automatically
  One template → many host-specific configs
```

**Q5: What is the variable precedence order?**

```
From lowest to highest:
  Role defaults  →  group_vars  →  host_vars  →  play vars
  →  task vars  →  set_fact  →  extra vars (-e)

Key rules:
  -e always wins (highest priority — use for CI overrides)
  host_vars beats group_vars (more specific wins)
  task vars only apply to that specific task
  role defaults are designed to be overridden

Practical example:
  defaults/main.yml:    nginx_port: 80      ← lowest
  group_vars/prod.yml:  nginx_port: 443     ← overrides default
  host_vars/web1.yml:   nginx_port: 8443   ← overrides group
  -e nginx_port=9090                        ← always wins

Use defaults for: values you want easily overridable
Use vars/ for: values that shouldn't be overridden
Use -e for: CI/CD-time overrides (version, environment)
```

**Q6: How do you handle secrets in Ansible?**

```
Never commit plaintext secrets to git. Use ansible-vault:

1. Create encrypted vault file:
   ansible-vault create group_vars/all/vault.yml
   # Enter: db_password: MyStr0ngP@ss

2. Reference in playbook like any variable:
   - name: Set DB password
     shell: "mysql -e \"SET PASSWORD='{{ db_password }}';\""
     no_log: true    # prevent secret showing in logs

3. Run with vault password:
   ansible-playbook site.yml --vault-password-file .vault_pass
   # .vault_pass in .gitignore, never committed

4. In CI/CD (GitHub Actions):
   Store vault password as GitHub Secret
   echo "${{ secrets.VAULT_PASS }}" > .vault_pass
   ansible-playbook site.yml --vault-password-file .vault_pass
   rm .vault_pass   # cleanup after

Best practice structure:
  group_vars/all/vars.yml       ← regular vars (commit)
  group_vars/all/vault.yml      ← encrypted (safe to commit)
  .vault_pass                   ← in .gitignore (never commit)
```

**Q7: What is the difference between command, shell, and raw modules?**

```
command:
  Runs command directly (no shell interpreter)
  No: pipes |, redirects >, env vars $VAR, wildcards *
  Safer: no shell injection risk
  Use when: simple commands, no shell features needed
  ansible.builtin.command: cmd: nginx -t

shell:
  Runs via /bin/sh
  Supports: pipes, redirects, env vars, wildcards
  Less safe: potential shell injection with user input
  Use when: you specifically need shell features
  ansible.builtin.shell: cmd: ps aux | grep nginx | wc -l

raw:
  Runs command via raw SSH (no Python needed)
  No return code in JSON format
  Use when: Python not installed yet (bootstrap)
  ansible.builtin.raw: dnf install -y python3

Rule: prefer command > shell > raw
Only use shell if you need shell features (pipes, etc.)
Only use raw for bootstrapping nodes without Python
```

---

## QUICK REFERENCE

### Ansible Command Cheatsheet

```bash
# ─── AD-HOC COMMANDS ──────────────────────────────────────────
ansible all -m ping                           # test connectivity
ansible all -m gather_facts                   # collect facts
ansible webservers -m command -a "uptime"     # run command
ansible all -m service -a "name=nginx state=restarted" --become
ansible webservers -m copy -a "src=file.txt dest=/tmp/"

# ─── PLAYBOOK ─────────────────────────────────────────────────
ansible-playbook site.yml
ansible-playbook site.yml --check --diff      # dry run
ansible-playbook site.yml --limit webservers
ansible-playbook site.yml --tags nginx
ansible-playbook site.yml --skip-tags deploy
ansible-playbook site.yml -v / -vv / -vvv    # verbose
ansible-playbook site.yml --syntax-check      # validate syntax
ansible-playbook site.yml --list-tasks        # list all tasks
ansible-playbook site.yml --list-hosts        # list target hosts

# ─── VAULT ────────────────────────────────────────────────────
ansible-vault create secrets.yml
ansible-vault encrypt secrets.yml
ansible-vault decrypt secrets.yml
ansible-vault view secrets.yml
ansible-vault edit secrets.yml
ansible-vault rekey secrets.yml
ansible-vault encrypt_string 'value' --name 'var_name'

# ─── INVENTORY ────────────────────────────────────────────────
ansible-inventory --list                      # list all hosts
ansible-inventory --graph                     # tree view
ansible-inventory --host web1                 # vars for host

# ─── GALAXY ───────────────────────────────────────────────────
ansible-galaxy role install geerlingguy.nginx
ansible-galaxy role install -r requirements.yml
ansible-galaxy role init roles/myrole        # create role structure
ansible-galaxy collection install amazon.aws

# ─── DOCS ─────────────────────────────────────────────────────
ansible-doc dnf                              # docs for dnf module
ansible-doc -l                               # list all modules
ansible-doc -t inventory aws_ec2             # inventory plugin docs
```

### Complete Project Structure

```
ansible-project/
├── ansible.cfg                 ← project config
├── site.yml                    ← main playbook
├── requirements.yml            ← role/collection dependencies
├── .vault_pass                 ← NEVER commit (in .gitignore)
├── .gitignore                  ← ignore .vault_pass, *.retry
│
├── inventory/
│   ├── aws_ec2.yml            ← dynamic inventory
│   ├── static_hosts.yml       ← static hosts
│   ├── group_vars/
│   │   ├── all/
│   │   │   ├── vars.yml       ← global vars
│   │   │   └── vault.yml      ← encrypted secrets
│   │   ├── webservers.yml     ← webserver vars
│   │   └── dbservers.yml      ← database vars
│   └── host_vars/
│       └── web1.example.com.yml
│
├── roles/
│   ├── common/                ← base configuration for all hosts
│   │   ├── tasks/main.yml
│   │   ├── handlers/main.yml
│   │   └── defaults/main.yml
│   ├── nginx/                 ← nginx configuration
│   │   ├── tasks/main.yml
│   │   ├── handlers/main.yml
│   │   ├── templates/
│   │   │   ├── nginx.conf.j2
│   │   │   └── vhost.conf.j2
│   │   ├── files/
│   │   │   └── mime.types
│   │   ├── defaults/main.yml
│   │   └── meta/main.yml
│   └── judicial-api/
│       ├── tasks/main.yml
│       ├── templates/
│       └── defaults/main.yml
│
├── playbooks/
│   ├── deploy-app.yml         ← app deployment
│   ├── update-packages.yml    ← OS updates
│   └── backup.yml             ← backup tasks
│
└── .github/
    └── workflows/
        └── deploy.yml         ← CI/CD pipeline
```

### Module Quick Reference

```
Package:   dnf, yum, apt, package (OS-agnostic)
File:      file, copy, template, fetch, lineinfile, blockinfile, find
Service:   service, systemd
User:      user, group, authorized_key
Command:   command, shell, raw, script, expect
Network:   uri, get_url, wait_for
Archive:   unarchive, archive
Cloud:     amazon.aws.ec2_instance, amazon.aws.s3_object
Debug:     debug, assert, fail
Facts:     setup, set_fact, gather_facts
Meta:      meta, include_tasks, import_tasks, include_role, import_role
```

### Jinja2 Filters Cheatsheet

```jinja2
{{ value | default('fallback') }}         if undefined use fallback
{{ string | upper }}                      UPPERCASE
{{ string | lower }}                      lowercase
{{ string | title }}                      Title Case
{{ string | replace('old', 'new') }}      replace substring
{{ list | join(', ') }}                   join list with separator
{{ list | unique }}                       remove duplicates
{{ list | sort }}                         sort list
{{ list | length }}                       count items
{{ dict | dict2items }}                   dict to [{key:, value:}]
{{ items | items2dict }}                  [{key:, value:}] to dict
{{ number | int }}                        convert to integer
{{ value | bool }}                        convert to boolean
{{ path | basename }}                     /etc/nginx.conf → nginx.conf
{{ path | dirname }}                      /etc/nginx.conf → /etc
{{ string | regex_replace('^prefix', '') }} regex replace
{{ value | to_json }}                     convert to JSON string
{{ json_str | from_json }}               parse JSON string
{{ value | to_yaml }}                     convert to YAML
{{ password | password_hash('sha512') }}  hash password
{{ lookup('env', 'HOME') }}              read environment variable
{{ lookup('file', '/etc/hostname') }}    read file content
```
