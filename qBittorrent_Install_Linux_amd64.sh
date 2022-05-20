#!/usr/bin/env bash

wget -O /usr/bin/qbittorrent-nox https://github.com/userdocs/qbittorrent-nox-static/releases/download/latest/x86_64-cmake-icu-qbittorrent-nox
chmod +x /usr/bin/qbittorrent-nox

cat > /etc/systemd/system/qbittorrent.service << EOF 
[Unit]
Description=qBittorrent-nox service
Wants=network-online.target
After=network-online.target nss-lookup.target

[Service]
Type=exec
User=root
ExecStart=/usr/bin/qbittorrent-nox
Restart=on-failure
ExecStop=/usr/bin/killall -w qbittorrent-nox
SyslogIdentifier=qbittorrent-nox

[Install]
WantedBy=multi-user.target
EOF

systemctl enable qBittorrent
