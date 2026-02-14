# 🚀 DirectAdmin Check WP-Admin

Readme: [Português](README-ptbr.md)

![License](https://img.shields.io/github/license/sr00t3d/directadmin-checkwp-admin)
![Shell Script](https://img.shields.io/badge/shell-script-green)

checkwpadmin.sh is a security auditing tool developed for DirectAdmin servers. Its critical objective is to scan all user accounts, identify WordPress installations, and list users with Administrator privileges who are not part of the team whitelist (e.g.: root@domain or dev@domain).

Ideal for identifying suspicious, forgotten administrative accounts or accounts created by attackers on shared servers.

🚀 Main Features

- **Global Scan**: Automatically iterates through all DirectAdmin users (`/home/*/domains/*/public_html`).
- **WordPress Detection**: Validates whether the directory contains an active WP installation.
- **Admin Audit (WP-CLI)**: Uses wp user list to extract users with the administrator role.
- **Security Mode**: Executes commands with --skip-plugins and --skip-themes to ensure the audit works even on sites with fatal errors or conflicts.
- **Smart Whitelist**: Ignores default infrastructure administrative users (e.g.: *`@domain.com.br`), focusing only on unknown users.
- **CSV Report**: Generates a consolidated `.csv` file with: `Date`, `DA User`, `Domain`, `Total Suspicious Admins`, `Login List`.
- **Visual Feedback**: Displays a progress bar during execution in the terminal.
- **Email Alert**: Automatically sends the final report to the configured email.

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

Edit the script header to adjust the email whitelist or the report recipient:

```bash
# Example of internal variables
EMAIL_REPORT="your-email@domain.com.br"
WHITELIST_EMAILS="root@domain.com.br dev@domain.com.br"
```

**3. Execution**

Run the script as root to ensure access to all user directories:

```bash
./da-checkwpadmin.sh
```

## 📊 Report Structure (CSV)

The generated file (`relatorio_admins_wp.csv`) follows the pattern:

```
DOMAIN    COUNTER    ADMIN_LIST
site.com  4          hacked1  noobmaster3  lolhehehe  igotyoursite
```

## ⚠️ Error Handling

- The script was designed to **not interrupt** execution if it encounters a broken site. It:
- Ignores PHP errors from the site (via WP-CLI flags).
- Records "Error reading WP" in the report if wp-config.php is unreadable or the database is inaccessible.

## ⚠️ Disclaimer

> [!WARNING]
> This software is provided "as-is". While extensively tested in DirectAdmin and WordPress environments. The author is not responsible for any data loss.

## 📚 Detailed Tutorial

For a complete step-by-step guide on how to import the generated files into Thunderbird and troubleshoot common migration issues, check out my full article:

👉 [**Mass Check Admins in WordPress on DirectAdmin**](https://perciocastelo.com.br/blog/mass-check-admins-in-wordPress-on-directAdmin.html)

## License 📄

This project is licensed under the **GNU General Public License v3.0**. See the [LICENSE](LICENSE) file for details.
