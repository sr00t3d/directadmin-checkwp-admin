# 🚀 DirectAdmin Check WP-Admin

Readme: [Português](README-ptbr.md)

![License](https://img.shields.io/github/license/sr00t3d/directadmin-checkwp-admin)
![Shell Script](https://img.shields.io/badge/shell-script-green)

`da-checkwpadmin.sh` is a security auditing tool developed for DirectAdmin
servers. Its critical objective is to scan all user accounts, identify
WordPress installations, and list users with Administrator privileges who are
not part of the team whitelist (for example:
`root@dominio.com.br` or `dev@dominio.com.br`).

Ideal for identifying suspicious, forgotten administrative accounts or accounts created by attackers on shared servers.

🚀 Main Features

- **Global Scan**: Automatically iterates through all DirectAdmin users
  (`/home/*`), checking WordPress installs in `/home/<user>/public_html`.
- **WordPress Detection**: Validates whether the directory contains an active WP installation.
- **Admin Audit (WP-CLI)**: Uses wp user list to extract users with the administrator role.
- **Security Mode**: Executes commands with --skip-plugins and --skip-themes to ensure the audit works even on sites with fatal errors or conflicts.
- **Smart Whitelist**: Ignores default infrastructure administrative users (e.g.: *`@domain.com.br`), focusing only on unknown users.
- **Daily CSV report**: Generates a consolidated file in
  `status_admins_wp_YYYYMMDD.csv` format.
- **Visual Feedback**: Displays a progress bar during execution in the terminal.
- **Email Alert**: Automatically sends the final report to the configured email.
- **Execution audit log**: Registers audit start/end time, generated file, and
  email delivery status in `/var/log/wp_audit.log`.
- **PT/EN messages**: Automatically adjusts terminal messages and email content
  based on `LANG`.

🛠️ Prerequisites
- Server with **DirectAdmin** and **root** access.
- **WP-CLI** installed and globally accessible.
- `mail` package or similar configured to send the report.

## 📦 Installation and Usage

**1. Script Download**

```bash
wget https://raw.githubusercontent.com/sr00t3d/directadmin-checkwp-admin/refs/heads/main/da-checkwpadmin.sh
chmod +x da-checkwpadmin.sh
```
**2. Configuration (Optional)**

Edit the script header to adjust recipient, whitelist, and audit options:

```bash
# Example of internal variables
RECIPIENT_MAIL="your-email@domain.com.br"
WHITELIST_EMAILS="root@domain.com.br dev@domain.com.br"
CSV_FILE="status_admins_wp_$(date +%Y%m%d).csv"
LOG_FILE="/var/log/wp_audit.log"
```

**3. Execution**

Run the script as root to ensure access to all user directories:

```bash
./da-checkwpadmin.sh
```

## 📊 Report Structure (CSV)

The generated file (`status_admins_wp_YYYYMMDD.csv`) follows the pattern:

```
DOMAIN    COUNTER    ADMIN_LIST
site.com  4          hacked1  noobmaster3  lolhehehe  igotyoursite
```

## 🧾 Audit trail

In addition to the CSV, the script writes an execution history to
`/var/log/wp_audit.log` including:

- Audit start date/time.
- Audit end date/time.
- Generated CSV filename.
- Email result (success, failure, or missing `mail` command).

## ⚠️ Error Handling

- The script was designed to **not interrupt** execution if it encounters a broken site. It:
- Ignores PHP errors from the site (via WP-CLI flags).
- Records "Error reading WP" in the report if wp-config.php is unreadable or the database is inaccessible.

## ⚠️ Legal Notice

> [!WARNING]
> This software is provided "as is". Always make sure to test first in a development environment. The author is not responsible for any misuse, legal consequences, or data impact caused by this tool.

## 📚 Detailed Tutorial

For a complete step-by-step guide, check out my full article:

👉 [**Mass Check Admins in WordPress on DirectAdmin**](https://perciocastelo.com.br/blog/mass-check-admins-in-wordPress-on-directAdmin.html)

## License 📄

This project is licensed under the **GNU General Public License v3.0**. See the [LICENSE](LICENSE) file for details.
