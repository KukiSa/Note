#!/usr/bin/env bash

set -eo pipefail
trap 'rm -rf $vw_temp_path' EXIT
stty erase ^?

port_test() {
    local port=$1
    while true; do
        if [[ $port =~ ^[0-9]{1,5}$ ]] && [[ $port -ge 0 ]] && [[ $port -le 65535 ]]; then
            if ! ss -tnlp | grep -q ":${port}"; then
                break
            else
                read -rp "Port $port is already in use, please enter another port: " port
            fi
        else
            read -rp "Invalid port, please enter a port between 0 and 65535: " port
        fi
    done
    echo "$port"
}

null_check() {
    local string_text=$1
    while true; do
        if [ -z "$string_text" ]; then
            read -rp "Null values are prohibited! please enter again:" string_text
        else
            break
        fi
    done
    echo "$string_text"
}

pkg_ins() {
    if [ "$(uname -m)" != "x86_64" ]; then
        echo "Non-x86_64 architectures are not currently supported, exiting..."
        exit 1
    fi
    source /etc/os-release || source /usr/lib/os-release || exit 1
    if [[ $ID == "centos"  || $ID == "amzn"  || $ID == "ol" ]]; then
        yum update
        yum install -y curl iproute jq openssl util-linux
    elif [[ $ID == "debian" || $ID == "ubuntu" ]]; then
        apt update
        apt-get install -y curl iproute2 jq openssl uuid-runtime
    else
        echo "This distribution is not currently supported, exiting..."
        exit 1
    fi
    echo "Package Install Completed, continue..."
}

env_pre() {
    vw_uuid_temp="$(uuidgen | tr -d '-')"
    vw_temp_path="$(mktemp -d -t bash-private-$vw_uuid_temp-$0-XXXXXX)"
    vw_temp_out="$vw_temp_path/output"
    mkdir $vw_temp_out
}

install_check() {
    if [ -f /var/lib/vaultwarden/version.json ]; then
        curl -s https://hub.docker.com/v2/repositories/vaultwarden/server/tags/alpine | jq -r '.images[] | select(.architecture == "amd64") | {architecture, digest}' > $vw_temp_path/latest.json
        if diff $vw_temp_path/latest.json /var/lib/vaultwarden/version.json; then
            echo "Vaultwarden is installed and up to date, exiting..."
            exit 1
        else
            echo "Vaultwarden is installed, but not the latest version. This installation will upgrade Vaultwarden."
            bash -c "$(curl -L https://github.com/KukiSa/Note/raw/main/vaultwarden-update.sh)"
            exit 0
        fi
    else
        echo "Vaultwarden is not installed, and it will be freshly installed."
    fi
}

get_info() {
    echo "Please select the database type:"
    while true; do
        echo "1. SQLite"
        echo "2. MariaDB"
        echo "3. MySQL"
        echo "4. PostgreSQL"
        read -rp "Enter your choice: " dbchoice
        case $dbchoice in
            1)
                dbtype="sqlite"
                break
                ;;
            2)
                dbtype="mysql"
                std_add="mariadb.service"
                break
            ;;
            3)
                dbtype="mysql"
                std_add="mysqld.service"
                break
            ;;
            4)
                dbtype="postgresql"
                std_add="postgresql.service"
                break
            ;;
            *)
                echo "Invalid choice, please enter again."
            ;;
        esac
    done
    if [ $dbtype == "sqlite" ]; then
        read -rp "SQLite Database File Path (Default: data/db.sqlite3):" dburl
        [ -z "$dburl" ] && dburl="data/db.sqlite3"
    else
        read -rp "Database User:" dbuser
        dbuser=$(null_check $dbuser)
        read -rp "Database Password:" dbpwd
        dbpwd=$(null_check $dbpwd)
        read -rp "Database Name:" dbname
        dbname=$(null_check $dbname)
        read -rp "Database Host (Default: 127.0.0.1):" dbhost
        [ -z "$dbhost" ] && dbhost="127.0.0.1"
        read -rp "Database Port (Default: 3306 or 5432):" dbport
        if [ $dbtype == "postgresql" ]; then
            [ -z "$dbport" ] && dbport="5432"
        else
            [ -z "$dbport" ] && dbport="3306"
        fi
        dburl="$dbtype://$dbuser:$dbpwd@$dbhost:$dbport/$dbname"
    fi
    read -rp "Server Domain or IP Address (No https:// , default: vaultwarden.example.com):" srvfqdn
    [ -z "$srvfqdn" ] && srvfqdn="vaultwarden.example.com"
    read -rp "Websocket Port (Default: 3012):" wsport
    [ -z "$wsport" ] && wsport="3012"
    wsport=$(port_test $wsport)
    read -rp "Rocket Port (Default: 8000):" rkport
    [ -z "$rkport" ] && rkport="8000"
    rkport=$(port_test $rkport)
    while true; do
        if [ $rkport == $wsport ]; then
            read -rp "Rocket Port and Websocket Port cannot be the same, please re-enter Rocket Port:" rkport
            rkport=$(port_test $rkport)
        else
            break
        fi
    done
    admintoken=$(openssl rand -base64 48)
}

main_install() {
    curl -s https://hub.docker.com/v2/repositories/vaultwarden/server/tags/alpine | jq -r '.images[] | select(.architecture == "amd64") | {architecture, digest}' > $vw_temp_path/latest.json
    curl -o $vw_temp_path/docker-image-extract https://raw.githubusercontent.com/jjlin/docker-image-extract/main/docker-image-extract
    chmod +x $vw_temp_path/docker-image-extract
    $vw_temp_path/docker-image-extract -o $vw_temp_out vaultwarden/server:alpine
    cp -f $vw_temp_out/vaultwarden /usr/bin/vaultwarden
    chmod +x /usr/bin/vaultwarden
    mkdir -p /var/lib/vaultwarden/data /var/lib/vaultwarden/web-vault
    cp -r $vw_temp_out/web-vault/. /var/lib/vaultwarden/web-vault
    useradd -s /sbin/nologin -M vaultwarden
    chown -R vaultwarden /var/lib/vaultwarden/data
    chown -R vaultwarden /var/lib/vaultwarden/web-vault
    cat > /etc/vaultwarden.env <<EOF
DATA_FOLDER=/var/lib/vaultwarden/data
DATABASE_URL=$dburl
IP_HEADER=X-Real-IP
ICON_CACHE_TTL=2592000
ICON_CACHE_NEGTTL=259200
WEB_VAULT_FOLDER=/var/lib/vaultwarden/web-vault
WEB_VAULT_ENABLED=true
ADMIN_TOKEN=$admintoken
DOMAIN=https://$srvfqdn
WEBSOCKET_ENABLED=true
WEBSOCKET_ADDRESS=127.0.0.1
WEBSOCKET_PORT=$wsport
ROCKET_ADDRESS=127.0.0.1
ROCKET_PORT=$rkport
ROCKET_WORKERS=10
EOF
    cat > /etc/systemd/system/vaultwarden.service <<EOF
[Unit]
Description=Vaultwarden Server
Documentation=https://github.com/dani-garcia/vaultwarden
After=network.target $std_add
Requires=$std_add

[Service]
User=vaultwarden
Group=vaultwarden
EnvironmentFile=/etc/vaultwarden.env
ExecStart=/usr/bin/vaultwarden
LimitNOFILE=1048576
LimitNPROC=64
PrivateTmp=true
PrivateDevices=true
ProtectHome=true
ProtectSystem=strict
WorkingDirectory=/var/lib/vaultwarden
ReadWriteDirectories=/var/lib/vaultwarden
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF
    if [ $dbtype == "sqlite" ]; then
        sed -i '5d' /etc/systemd/system/vaultwarden.service
    fi
    curl -s https://hub.docker.com/v2/repositories/vaultwarden/server/tags/alpine | jq -r '.images[] | select(.architecture == "amd64") | {architecture, digest}' > /var/lib/vaultwarden/version.json
    systemctl daemon-reload
    systemctl enable vaultwarden
    systemctl start vaultwarden
    echo "Install completed!"
    exit 0
}

pkg_ins
env_pre
install_check
get_info
main_install
