# Introduction to iks' Note Repository

## dn42
Something about DN42, like some scripts and configs. Currently there is only a file about automatically downloading DN42 network-wide ROA files from Burble's website and applying to cron jobs in bird2 configurations.

## re-proxy-for-MoeLink
See https://github.com/KukiSa/Note/blob/main/re-proxy-for-MoeLink/README.md

## 01_avatar_middle.jpg
A medium image of the avatar of the hostloc forum administrator `cpuer`.

## install-ISRG_Root_X1.bat
A batch for automatic installation of the ISRG Root X1 root certificate on Microsoft Windows 7, needs to be run as administrator.

## qBittorrent_Install_Linux_amd64.sh
A shell script for automatic installation of the latest version of qBittorrent (Qt6, cmake) for Linux distributions on x86_64 architecture. Requires `wget` and `systemd`.

## vaultwarden-install.sh & vaultwarden-update.sh
A shell script for automatic installation or upgrading Vaultwarden for Linux distributions on x86_64 architecture. The Vaultwarden binary and Web Vault files come from the official Vaultwarden Alpine Docker image.

The script hard-codes the binary file storage path and data storage path officially recommended by Vaultwarden, and includes the necessary basic settings.

Execute `bash -c "$(curl -L https://github.com/KukiSa/Note/raw/main/vaultwarden-install.sh)"` to install Vaultwarden. If MariaDB, MySQL or PostgreSQL is used as the database, please create the corresponding database in advance and write down the database type, database connection address, database user name, database password and database name.

Requires `systemd` and `crontab` for automatic upgrades. It is recommended that you execute `vaultwarden-update.sh` daily to check for and automatically install possible updates.
