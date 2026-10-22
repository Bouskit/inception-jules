# Developer documentation

This document explains how to set up the Inception project from scratch on a fresh machine, how to build and run it, how to manage its containers and volumes, and where its data lives.

---

## 1. Prerequisites

### 1.1 Host system

The project is developed and tested on a **virtual machine** (VirtualBox) running:

| Item | Value |
|---|---|
| OS | **Debian 13 (trixie)**, amd64 |
| Desktop | Xfce (optional, only needed to open the site in a browser) |
| CPU | 2 vCPUs recommended |
| RAM | 4 GB recommended (2 GB minimum) |
| Disk | 20 GB recommended (the images take about 2.5 GB with the bonus, plus the data and the backups) |
| Network | Internet access (images are built from scratch: `apt` packages, WP-CLI, Adminer and WordPress are downloaded during the build and the first start) |

> The **host** runs Debian 13, but the **containers** are built from `debian:bookworm` (Debian 12), the penultimate stable version, as required by the subject.

### 1.2 Give your user `sudo` rights

Many setup commands need administrator rights. If you set a root password during the Debian installation, your user is **not** in the `sudo` group by default.

```bash
su -                          # become root (asks for the root password)
apt update && apt install -y sudo
usermod -aG sudo bboukach     # add your user to the sudo group
exit                          # leave the root shell
```

Then **log out and log back in** (group changes only apply to new sessions), and check:

```bash
groups                        # must list "sudo"
sudo whoami                   # must print "root"
```

### 1.3 Install basic tools

```bash
sudo apt update
sudo apt install -y make git curl ca-certificates openssl
```

- `make`: runs the project `Makefile`.
- `git`: clones the repository.
- `curl`, `ca-certificates`: needed to add the Docker repository, and to test the site and the FTP server.
- `openssl`: only used to test TLS from the host (`openssl s_client`).

### 1.4 Install Docker Engine and the Compose plugin

Docker is installed from **Docker's official `apt` repository** (the `docker.io` package shipped by Debian is not used). These steps follow the official guide: <https://docs.docker.com/engine/install/debian/>.

**a) Remove conflicting unofficial packages** (`apt` may report that none are installed, which is fine):

```bash
sudo apt remove $(dpkg --get-selections docker.io docker-compose docker-doc docker-buildx podman-docker containerd runc | cut -f1)
```

**b) Add Docker's signing key and repository:**

```bash
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
```

**c) Install the packages:**

```bash
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

- `docker-ce`: the Docker daemon (the background service that runs containers).
- `docker-ce-cli`: the `docker` command.
- `containerd.io`: the low-level runtime used by the daemon.
- `docker-buildx-plugin`: the image builder (BuildKit).
- `docker-compose-plugin`: the `docker compose` command (Compose v2, written with a space).

**d) Check that the daemon runs and starts with the machine:**

```bash
sudo systemctl status docker      # must show "active (running)"
systemctl is-enabled docker       # must print "enabled"
```

If it is not enabled: `sudo systemctl enable --now docker`. This matters: after a reboot, the containers only come back automatically if the Docker daemon starts with the machine.

### 1.5 Use Docker without `sudo`

By default, only root can talk to the Docker daemon. Add your user to the `docker` group:

```bash
sudo usermod -aG docker bboukach
```

Then **log out and log back in** (or run `newgrp docker` in the current terminal), and check:

```bash
groups                                               # must list "docker"
docker --version
docker compose version
docker run --rm debian:bookworm echo "Docker works"
```

The last command downloads the `debian:bookworm` base image (the only image the project is allowed to pull) and runs a throwaway container.

> **Security note:** being in the `docker` group is almost equivalent to being root, since any member can start a root container that mounts any folder of the host. Only add trusted users.

### 1.6 Configure Git (for commits)

```bash
git config --global user.name "bboukach"
git config --global user.email "bboukach@student.42luxembourg.lu"
```

---

## 2. Setting up the project from scratch

### 2.1 Get the sources

```bash
git clone <repository-url> ~/inception
cd ~/inception
```

The repository does **not** contain `srcs/.env` nor the `secrets/` folder: both are ignored by Git on purpose (see `.gitignore`). You must create them.

### 2.2 Create the configuration file `srcs/.env`

```bash
cp srcs/.env.example srcs/.env
nano srcs/.env
```

| Variable | Used by | Meaning |
|---|---|---|
| `DOMAIN_NAME` | nginx, wordpress | Site domain, e.g. `bboukach.42.fr` |
| `MYSQL_DATABASE` | mariadb, wordpress, backup | Name of the WordPress database |
| `MYSQL_USER` | mariadb, wordpress, backup | MariaDB account used by WordPress |
| `WP_TITLE` | wordpress | Site title |
| `WP_ADMIN_USER` | wordpress | Administrator login. **Must not contain `admin`** (any case): the container refuses to start otherwise |
| `WP_ADMIN_EMAIL` | wordpress | Administrator email |
| `WP_USER` | wordpress | Second WordPress user (role: author) |
| `WP_USER_EMAIL` | wordpress | Second user's email |
| `FTP_USER` | ftp (bonus) | FTP login |

No password goes in this file.

### 2.3 Create the secrets

Passwords are stored as **Docker secrets**: one file per password in `secrets/`, at the root of the repository.

```bash
mkdir -p secrets
echo 'choose_a_password' > secrets/db_password.txt         # MariaDB password of MYSQL_USER
echo 'choose_a_password' > secrets/db_root_password.txt    # MariaDB root password
echo 'choose_a_password' > secrets/wp_admin_password.txt   # WordPress administrator password
echo 'choose_a_password' > secrets/wp_user_password.txt    # WordPress second user password
echo 'choose_a_password' > secrets/ftp_password.txt        # FTP password (bonus)
chmod 600 secrets/*.txt
```

Use different passwords. At runtime, Compose makes each file available, read-only, as `/run/secrets/<name>` **only** in the containers that declare it:

| Secret | mariadb | wordpress | nginx | ftp | backup | others |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| `db_password` | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ |
| `db_root_password` | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `wp_admin_password` | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `wp_user_password` | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `ftp_password` | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |

Before any commit, check that nothing sensitive is tracked:

```bash
git status            # neither secrets/ nor srcs/.env must appear
```

### 2.4 Point the domain to the local machine

```bash
sudo nano /etc/hosts
```

Add this line:

```
127.0.0.1   bboukach.42.fr
```

---

## 3. Building and launching

Everything is driven by the `Makefile` at the root of the repository, which calls `docker compose -f srcs/docker-compose.yml`. Bonus services belong to the Compose **profile** `bonus`: they are ignored unless the profile is enabled.

```bash
make            # mandatory part: mariadb, wordpress, nginx
make bonus      # mandatory part + website, adminer, redis, ftp, backup
```

`make` (rule `up`) does two things:

1. creates the data folders `/home/bboukach/data/mariadb` and `/home/bboukach/data/wordpress` (Docker does not create them itself with this volume configuration). `make bonus` also creates `/home/bboukach/data/backups`;
2. runs `docker compose up -d --build` (with `--profile bonus` for `make bonus`): builds the images from their Dockerfiles, creates the network, the volumes and the containers, and starts them in the background.

On the **first** start, wait about 20 seconds: MariaDB creates the database, then WordPress downloads and installs itself. Then open <https://bboukach.42.fr> (accept the self-signed certificate warning).

### Makefile rules

| Rule | Command | Effect |
|---|---|---|
| `make` / `make up` | `mkdir -p` + `up -d --build` | Build and start the mandatory part |
| `make bonus` | `mkdir -p` + `--profile bonus up -d --build` | Build and start everything |
| `make down` | `--profile bonus down` | Stop and **remove** all containers and the network. Data is kept |
| `make stop` | `--profile bonus stop` | Stop the containers without removing them |
| `make start` | `--profile bonus start` | Restart stopped containers |
| `make clean` | same as `down` | |
| `make fclean` | `--profile bonus down -v --rmi all` + `sudo rm -rf /home/bboukach/data` | Remove **everything**: containers, network, volumes, images, data and backups (asks for the `sudo` password) |
| `make re` | `fclean` then `all` | Full reinstall of the mandatory part |
| `make ps` | `--profile bonus ps` | Show the state of all containers |
| `make logs` | `--profile bonus logs` | Show the logs of all services |

The management rules enable the `bonus` profile so that they also see the bonus containers. Enabling a profile in these commands does not start anything.

---

## 4. Managing containers and volumes

### State and logs

```bash
make ps                                 # 3 containers (make) or 8 (make bonus)
docker logs wordpress                   # output of one container (its setup script)
docker logs -f mariadb                  # follow the logs live (Ctrl+C to quit)
```

nginx and php-fpm write their own logs to files inside their containers. The bonus services (website, redis, backup) log to the container output, so `docker logs` is enough.

```bash
docker exec nginx cat /var/log/nginx/error.log
docker exec nginx tail -n 20 /var/log/nginx/access.log
```

### Running commands inside a container

```bash
docker exec -it mariadb mariadb -u root -p          # MariaDB shell (root password from secrets/)
docker exec wordpress wp user list --allow-root --path=/var/www/html
docker exec wordpress wp post list --allow-root --path=/var/www/html
docker exec -it wordpress sh                        # interactive shell for inspection
```

`docker exec` starts an **additional** process in a running container; it does not affect the main process (PID 1).

### Images, network and volumes

```bash
docker images | grep inception          # one image per service, tagged :inception
docker network ls                       # srcs_inception
docker volume ls                        # srcs_db_data, srcs_wp_data (+ srcs_backup_data)
docker volume inspect srcs_db_data      # shows the device path in /home/bboukach/data
```

### Rebuilding after a change

```bash
make            # or make bonus: Compose rebuilds the images and recreates only the containers that changed
```

### Useful checks

```bash
curl -k -I https://bboukach.42.fr                     # expect "HTTP/1.1 200 OK"
curl -I http://bboukach.42.fr                         # expect "Connection refused" (no HTTP)
openssl s_client -connect bboukach.42.fr:443 < /dev/null 2>/dev/null | grep Protocol   # TLSv1.3
sudo ss -tlnp                                         # mandatory: only 443 is published by Docker
```

### Bonus services checks

```bash
curl -I http://bboukach.42.fr:8080                                       # website: 200 OK
curl -I http://127.0.0.1:8081                                            # adminer: 200 OK
docker exec redis redis-cli ping                                         # redis: PONG
docker exec wordpress wp redis status --allow-root --path=/var/www/html  # Status: Connected
curl -u ftpuser:"$(cat secrets/ftp_password.txt)" ftp://127.0.0.1/       # ftp: lists the WordPress files
docker exec backup /usr/local/bin/backup.sh                              # backup: runs a backup now
```

---

## 5. Where the data lives and how it persists

### The named volumes

| Volume | Mounted in | Contains | Stored on the host in |
|---|---|---|---|
| `db_data` | mariadb: `/var/lib/mysql` | The MariaDB data: the WordPress database (posts, users, settings) | `/home/bboukach/data/mariadb` |
| `wp_data` | wordpress, nginx, ftp: `/var/www/html`; backup: `/var/www/html` (read-only) | The WordPress files: PHP code, themes, plugins, uploaded images, `wp-config.php` | `/home/bboukach/data/wordpress` |
| `backup_data` (bonus) | backup: `/backups` | Dated backups (database dump + files archive) | `/home/bboukach/data/backups` |

All are Docker **named volumes** (declared in the `volumes:` section of `docker-compose.yml` and listed by `docker volume ls`). Their `driver_opts` (`type: none`, `o: bind`, `device: ...`) only tell the `local` driver **where** to store the data.

`wp_data` is mounted at the **same path** in wordpress and nginx: nginx only sends the path of a `.php` file to php-fpm, which must find the same file on its side. nginx itself only reads static files (CSS, JS, images).

> When listing these folders from the host, MariaDB files may show an unexpected owner (e.g. `dhcpcd`). Files store numeric UIDs: the `mysql` user of the container has a UID that matches another user on the host. Use `ls -ln` to see the numbers.

> When a named volume is **empty**, Docker copies the content of the image at the mount point into it the first time it is mounted. This is why Debian's nginx welcome page is removed from the nginx image: otherwise it could end up in the WordPress volume.

### What survives what

| Action | Containers | Volumes / data |
|---|---|---|
| Crash of a container | Restarted automatically (`restart: unless-stopped`) | Kept |
| `make stop` / `make start` | Same containers, paused then resumed | Kept |
| `make down` then `make` | New containers | Kept: the site comes back without reinstalling |
| Reboot of the VM | Restarted automatically by the Docker daemon | Kept |
| `make fclean` / `make re` | Removed | **Deleted, backups included** |

### First start vs. next starts

Each setup script detects whether it is the first start with a "witness" file:

- **mariadb** (`mdb-setup.sh`): if `/var/lib/mysql/mysql` is missing, it initializes the system tables; if `/var/lib/mysql/<MYSQL_DATABASE>` is missing, it creates the database and the user, and sets the root password.
- **wordpress** (`wp-setup.sh`): it waits for MariaDB at every start. If `wp-config.php` is missing, it downloads, configures and installs WordPress and creates the second user. Then, at every start, it enables the Redis cache if the `redis` container exists, or removes the `object-cache.php` drop-in and deactivates the plugin otherwise.
- **nginx** (`nginx-setup.sh`): if `/etc/nginx/ssl/cert.pem` is missing, it generates a self-signed certificate (kept in the container, regenerated when the container is recreated).
- **ftp** (`ftp-setup.sh`): it creates the FTP user if it does not exist yet (UID 33, shared with `www-data`), and sets its password at every start.
- **backup** (`backup-setup.sh`): it writes `/etc/backup.env` for the cron job, since cron jobs do not inherit the container environment.

Each script then runs its service in the foreground with `exec`, so that the service becomes PID 1. `website`, `adminer` and `redis` need no script: their Dockerfile `CMD` starts the service directly.

> **Keep both volumes in sync.** The WordPress files and the database belong together. If you delete one but not the other (e.g. remove only `/home/bboukach/data/wordpress`), the reinstall fails because the database already contains the users. Use `make fclean` to reset both. Note that `docker compose down -v` alone removes the volume *objects* but **not** the files in `/home/bboukach/data`.

---

## 6. Bonus services: technical notes

| Service | Base | Process (PID 1) | Port | Notes |
|---|---|---|---|---|
| website | nginx | `nginx -g "daemon off;"` | `8080` | Site files copied into the image from `site/` |
| adminer | `php-cli`, `php-mysql` | `php -S 0.0.0.0:8080` (as `www-data`) | `127.0.0.1:8081` | Adminer 6.0.1 (MySQL edition), downloaded at build time. `init: true` so that `SIGTERM` stops it |
| redis | `redis-server` | `redis-server` (as `redis`) | internal `6379` | Cache only: no persistence, 64 MB, `allkeys-lru` |
| ftp | `vsftpd` | `vsftpd` | `127.0.0.1:21`, `127.0.0.1:21100-21110` | Passive mode, chroot in `/var/www/html`, `pasv_address=127.0.0.1` |
| backup | `cron`, `mariadb-client` | `cron -f` | none | Daily at 03:00 UTC, keeps 7 backups. `init: true` |

**Connecting to Adminer:** server `mariadb`, user `MYSQL_USER`, password from `secrets/db_password.txt`, database `MYSQL_DATABASE`. `root` cannot log in from Adminer: the root account only exists as `root@localhost`, i.e. from inside the mariadb container.

### Backup and restore

A backup is a folder `/home/bboukach/data/backups/<YYYY-MM-DD_HH-MM-SS>/` containing `database.sql.gz` and `wordpress.tar.gz`. The folder is only readable by root (`sudo ls`).

```bash
docker exec backup /usr/local/bin/backup.sh                      # back up now
sudo ls /home/bboukach/data/backups                              # list the backups
docker exec backup /usr/local/bin/restore.sh <backup-name>       # restore the database
docker exec redis redis-cli flushall                             # then clear the cache
```

To also restore the **files** (the backup container mounts them read-only), extract the archive on the host:

```bash
sudo tar -xzf /home/bboukach/data/backups/<backup-name>/wordpress.tar.gz -C /home/bboukach/data/wordpress
```

`tar` run as root keeps the original owners (`www-data`).

To test the cron schedule itself, temporarily set the line of `conf/backup.cron` to `* * * * *` (every minute), run `make bonus`, wait a minute and check `docker logs backup`. A backup started with `docker exec` does not prove that cron works, since it inherits the container environment.

---

## 7. Project structure

```
inception/
├── Makefile                       # entry point: make, bonus, down, fclean, re...
├── secrets/                       # passwords, one per file (ignored by Git)
├── DEV_DOC.md / USER_DOC.md / README.md
└── srcs/
    ├── .env                       # non-secret configuration (ignored by Git)
    ├── .env.example               # template for .env
    ├── docker-compose.yml         # services, network, volumes, secrets, profiles
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── .dockerignore
        │   ├── conf/51-mdb.cnf    # bind-address = 0.0.0.0
        │   └── tools/mdb-setup.sh
        ├── wordpress/
        │   ├── Dockerfile         # php-fpm 8.2 + extensions + WP-CLI
        │   ├── .dockerignore
        │   ├── conf/www.conf      # php-fpm pool: listen on port 9000
        │   └── tools/wp-setup.sh
        ├── nginx/
        │   ├── Dockerfile
        │   ├── .dockerignore
        │   ├── conf/inception.conf  # HTTPS only, TLSv1.2/1.3, FastCGI to wordpress:9000
        │   └── tools/nginx-setup.sh
        └── bonus/
            ├── website/           # Dockerfile, conf/website.conf, site/ (HTML, CSS, images)
            ├── adminer/           # Dockerfile
            ├── redis/             # Dockerfile, conf/redis.conf
            ├── ftp/               # Dockerfile, conf/vsftpd.conf, tools/ftp-setup.sh
            └── backup/            # Dockerfile, conf/backup.cron, tools/{backup-setup,backup,restore}.sh
```

---

## Changing the login

The login appears in several places. To use another one, update:

- `Makefile`: the `LOGIN` variable;
- `srcs/docker-compose.yml`: the `device:` paths of the three volumes, and the nginx network alias;
- `srcs/.env`: `DOMAIN_NAME`;
- `srcs/requirements/nginx/conf/inception.conf`: `server_name`;
- `/etc/hosts`: the domain line.