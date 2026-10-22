# User documentation

This document explains, in simple terms, how to use the Inception stack: what it provides, how to start and stop it, how to reach the website and its administration panel, where the credentials are, and how to check that everything works.

> Commands are run from the root of the project folder (`~/inception`).

---

## 1. What the stack provides

The project runs a **WordPress website** made of three services, each in its own container:

| Service | Role | Reachable from outside? |
|---|---|---|
| **nginx** | Web server. The only entry point: it receives visitors on port **443** (HTTPS only), serves static files and forwards PHP pages to WordPress. | Yes, on port 443 |
| **wordpress** | WordPress with php-fpm. Runs the PHP code that builds the pages. | No (internal only) |
| **mariadb** | Database. Stores the posts, users and settings of the site. | No (internal only) |

The **bonus** adds five optional services:

| Service | Role | Reachable from |
|---|---|---|
| **website** | A small static showcase site | The VM and the network, port 8080 |
| **adminer** | A web page to browse and manage the database | The VM only, port 8081 |
| **redis** | A cache that makes WordPress faster | Internal only |
| **ftp** | File transfer to and from the WordPress files | The VM only, port 21 |
| **backup** | Automatic daily backup of the site | Internal only |

The site is available at **<https://bboukach.42.fr>**.

The data is kept between restarts:

- the database in `/home/bboukach/data/mariadb`;
- the website files (including uploaded images) in `/home/bboukach/data/wordpress`;
- the backups (bonus) in `/home/bboukach/data/backups`.

---

## 2. Starting and stopping the project

| Action | Command | What happens |
|---|---|---|
| Start | `make` | Builds what is needed and starts the three main containers |
| Start with the bonus | `make bonus` | Starts the eight containers |
| Stop (pause) | `make stop` | Stops the containers, keeps them |
| Resume | `make start` | Starts the stopped containers again |
| Stop and remove containers | `make down` | Containers are removed; **the site data is kept** |
| Reset everything | `make fclean` | ⚠️ **Deletes all data and backups** (posts, users, images). Asks for your `sudo` password |
| Reinstall from scratch | `make re` | `make fclean` then `make` (main services only) |

On the very first start, wait about **20 seconds** before opening the site: the database and WordPress are being installed.

The containers restart automatically if they crash, and after a reboot of the machine.

---

## 3. Accessing the services

| Page | Address |
|---|---|
| Website | <https://bboukach.42.fr> |
| Administration panel | <https://bboukach.42.fr/wp-admin> |
| Showcase site (bonus) | <http://bboukach.42.fr:8080> |
| Adminer (bonus) | <http://127.0.0.1:8081> |
| FTP (bonus) | `ftp://127.0.0.1` (port 21) |

**Security warning in the browser:** the site uses a *self-signed* certificate, so the browser shows a warning the first time (and again after the nginx container is recreated). This is expected. Click **Advanced → Accept the risk and continue**. The connection is still encrypted (TLS 1.2 or 1.3).

> If the address does not open at all, check that `/etc/hosts` contains the line `127.0.0.1   bboukach.42.fr`.

**Adminer** — fill in the login form with:

| Field | Value |
|---|---|
| System | MySQL / MariaDB |
| Server | `mariadb` |
| Username | `MYSQL_USER` from `srcs/.env` |
| Password | content of `secrets/db_password.txt` |
| Database | `MYSQL_DATABASE` from `srcs/.env` |

Logging in as `root` is refused on purpose: the root account only works from inside the database container.

**FTP** — Adminer and FTP only accept connections from the VM itself, because their passwords travel unencrypted. To list the WordPress files:

```bash
curl -u ftpuser:"$(cat secrets/ftp_password.txt)" ftp://127.0.0.1/
```

A graphical FTP client (e.g. FileZilla) also works, with host `127.0.0.1`, port `21` and passive mode.

---

## 4. Locating and managing credentials

Credentials are split into two places, both **outside of Git**:

| What | Where |
|---|---|
| Usernames, emails, domain | `srcs/.env` |
| Passwords | `secrets/` (one file per password) |

| Account | Username | Password file |
|---|---|---|
| WordPress administrator | `WP_ADMIN_USER` in `srcs/.env` | `secrets/wp_admin_password.txt` |
| WordPress second user (author) | `WP_USER` in `srcs/.env` | `secrets/wp_user_password.txt` |
| MariaDB account used by WordPress (and Adminer) | `MYSQL_USER` in `srcs/.env` | `secrets/db_password.txt` |
| MariaDB root | `root` | `secrets/db_root_password.txt` |
| FTP (bonus) | `FTP_USER` in `srcs/.env` | `secrets/ftp_password.txt` |

To read a password:

```bash
cat secrets/wp_admin_password.txt
```

**Important:** the WordPress and MariaDB passwords are only used during the **first installation**. Changing them later does not change existing accounts. The FTP password, however, is applied at every start of the ftp container.

- To change a WordPress password, use the administration panel (**Users → Profile**), then update the file so it stays accurate.
- To apply new values to everything (including the database passwords), reinstall with `make re`. ⚠️ This deletes the site data.

Never commit `srcs/.env` or `secrets/` to Git.

---

## 5. Checking that the services are running correctly

**1. Are the containers up?**

```bash
make ps
```

All containers (3 with `make`, 8 with `make bonus`) must show `Up`. A status `Restarting` means a container keeps failing: read its logs (step 3).

**2. Does the site answer?**

```bash
curl -k -I https://bboukach.42.fr
```

The first line must be `HTTP/1.1 200 OK`. You can also simply open the site in the browser.

**3. What do the services say?**

```bash
make logs                    # all services
docker logs wordpress        # one service
```

Errors from the setup scripts are explicit, for example `Error : WP_TITLE variable is empty` or `Error : MariaDB not responding`.

**4. Does WordPress consider itself healthy?**

In the administration panel, open **Tools → Site Health**. Two remaining notices are expected and justified:

- the optional `imagick` module is not installed (the `gd` module is used instead);
- PHP 8.2 is used, because it is the version provided by Debian bookworm, imposed by the subject.

With the bonus, **Settings → Redis** must show the cache as connected.

**Common problems**

| Symptom | Likely cause | What to do |
|---|---|---|
| Browser cannot find the site | Domain missing from `/etc/hosts` | Add `127.0.0.1   bboukach.42.fr` |
| `403 Forbidden` right after the first start | WordPress is still being installed | Wait 20 seconds and reload |
| `Error establishing a database connection` | MariaDB is (re)starting | Wait a few seconds; check `docker logs mariadb` |
| A container is `Restarting` | Missing or wrong configuration | Read `docker logs <service>` |
| `make` fails with a message about a secret file | A file is missing in `secrets/` | Create it (see `DEV_DOC.md`) |
| A change does not appear on the site with the bonus | Redis still serves the old version | Run `docker exec redis redis-cli flushall` |

---

## 6. Backups (bonus)

With `make bonus`, the site is **backed up automatically every day** at 03:00 UTC (database and files). The 7 most recent backups are kept in `/home/bboukach/data/backups`.

```bash
docker logs backup                                         # history of the backups
docker exec backup /usr/local/bin/backup.sh                # make a backup now
sudo ls /home/bboukach/data/backups                        # list the backups
docker exec backup /usr/local/bin/restore.sh <name>        # restore the database from a backup
docker exec redis redis-cli flushall                       # then clear the cache
```

`restore.sh` without a name lists the available backups. Restoring the files as well is described in `DEV_DOC.md`.

⚠️ `make fclean` also deletes the backups.