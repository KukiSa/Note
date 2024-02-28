#!/usr/bin/env bash

set -eo pipefail
trap 'rm -rf $__vw_temp_path; unset __port; unset __string_text; unset __vw_uuid_temp; unset __vw_temp_path; unset __vw_temp_out; unset __dbchoice; unset __dbtype; unset __std_add; unset __dburl; unset __dbuser; unset __dbpwd; unset __dbname; unset __dbhost; unset __dbport; unset __srvfqdn; unset __wsport; unset __rkport; unset __admin_token' EXIT
stty erase ^?

port_test() {
    local __port=$1
    while true; do
        if [[ $__port =~ ^[0-9]{1,5}$ ]] && [[ $__port -ge 0 ]] && [[ $__port -le 65535 ]]; then
            if ! ss -tnlp | grep -q ":${__port}"; then
                break
            else
                read -rp "Port $__port is already in use, please enter another port: " __port
            fi
        else
            read -rp "Invalid port, please enter a port between 0 and 65535: " __port
        fi
    done
    echo "$__port"
}

null_check() {
    local __string_text=$1
    while true; do
        if [ -z "$__string_text" ]; then
            read -rp "Null values are prohibited! please enter again:" __string_text
        else
            break
        fi
    done
    echo "$__string_text"
}

pkg_ins() {
    if [ "$(uname -m)" != "x86_64" ]; then
        echo "Non-x86_64 architectures are not currently supported, exiting..."
        exit 1
    fi
    source /etc/os-release || source /usr/lib/os-release || exit 1
    if [[ $ID == "centos"  || $ID == "amzn"  || $ID == "ol" ]]; then
        yum update
        yum install -y coreutils curl iproute jq openssl util-linux
    elif [[ $ID == "debian" || $ID == "ubuntu" ]]; then
        apt update
        apt-get install -y coreutils curl iproute2 jq openssl uuid-runtime
    else
        echo "This distribution is not currently supported, exiting..."
        exit 1
    fi
    echo "Package Install Completed, continue..."
}

env_pre() {
    __vw_uuid_temp="$(uuidgen | tr -d '-')"
    __vw_temp_path="$(mktemp -d -t bash-private-$__vw_uuid_temp-$(basename $0)-XXXXXX)"
    __vw_temp_out="$__vw_temp_path/output"
    mkdir $__vw_temp_out
}

install_check() {
    if [ -f /var/lib/vaultwarden/version.json ]; then
        curl -s https://hub.docker.com/v2/repositories/vaultwarden/server/tags/alpine | jq -r '.images[] | select(.architecture == "amd64") | {architecture, digest}' > $__vw_temp_path/latest.json
        if diff $__vw_temp_path/latest.json /var/lib/vaultwarden/version.json; then
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
        read -rp "Enter your choice: " __dbchoice
        case $__dbchoice in
            1)
                __dbtype="sqlite"
                break
                ;;
            2)
                __dbtype="mysql"
                __std_add="mariadb.service"
                break
            ;;
            3)
                __dbtype="mysql"
                __std_add="mysqld.service"
                break
            ;;
            4)
                __dbtype="postgresql"
                __std_add="postgresql.service"
                break
            ;;
            *)
                echo "Invalid choice, please enter again."
            ;;
        esac
    done
    if [ $__dbtype == "sqlite" ]; then
        read -rp "SQLite Database File Path (Default: data/db.sqlite3):" __dburl
        [ -z "$__dburl" ] && __dburl="data/db.sqlite3"
    else
        read -rp "Database User:" __dbuser
        __dbuser=$(null_check $__dbuser)
        read -rp "Database Password:" __dbpwd
        __dbpwd=$(null_check $__dbpwd)
        read -rp "Database Name:" __dbname
        __dbname=$(null_check $__dbname)
        read -rp "Database Host (Default: 127.0.0.1):" __dbhost
        [ -z "$__dbhost" ] && __dbhost="127.0.0.1"
        read -rp "Database Port (Default: 3306 or 5432):" __dbport
        if [ $__dbtype == "postgresql" ]; then
            [ -z "$__dbport" ] && __dbport="5432"
        else
            [ -z "$__dbport" ] && __dbport="3306"
        fi
        __dburl="$__dbtype://$__dbuser:$__dbpwd@$__dbhost:$__dbport/$__dbname"
    fi
    read -rp "Server Domain or IP Address (No https:// , default: vaultwarden.example.com):" __srvfqdn
    [ -z "$__srvfqdn" ] && __srvfqdn="vaultwarden.example.com"
    read -rp "Websocket Port (Default: 3012):" __wsport
    [ -z "$__wsport" ] && __wsport="3012"
    __wsport=$(port_test $__wsport)
    read -rp "Rocket Port (Default: 8000):" __rkport
    [ -z "$__rkport" ] && __rkport="8000"
    __rkport=$(port_test $__rkport)
    while true; do
        if [ $__rkport == $__wsport ]; then
            read -rp "Rocket Port and Websocket Port cannot be the same, please re-enter Rocket Port:" __rkport
            __rkport=$(port_test $__rkport)
        else
            break
        fi
    done
    __admin_token=$(openssl rand -base64 48)
}

main_install() {
    curl -s https://hub.docker.com/v2/repositories/vaultwarden/server/tags/alpine | jq -r '.images[] | select(.architecture == "amd64") | {architecture, digest}' > $__vw_temp_path/latest.json
    curl -o $__vw_temp_path/docker-image-extract https://raw.githubusercontent.com/jjlin/docker-image-extract/main/docker-image-extract
    chmod +x $__vw_temp_path/docker-image-extract
    $__vw_temp_path/docker-image-extract -o $__vw_temp_out vaultwarden/server:alpine
    cp -f $__vw_temp_out/vaultwarden /usr/bin/vaultwarden
    chmod +x /usr/bin/vaultwarden
    mkdir -p /var/lib/vaultwarden/data /var/lib/vaultwarden/web-vault
    cp -r $__vw_temp_out/web-vault/. /var/lib/vaultwarden/web-vault
    useradd -s /sbin/nologin -M vaultwarden
    chown -R vaultwarden /var/lib/vaultwarden/data
    chown -R vaultwarden /var/lib/vaultwarden/web-vault
    cat > /etc/vaultwarden.env <<EOF
DATA_FOLDER=/var/lib/vaultwarden/data
DATABASE_URL=$__dburl
IP_HEADER=X-Real-IP
ICON_CACHE_TTL=2592000
ICON_CACHE_NEGTTL=259200
WEB_VAULT_FOLDER=/var/lib/vaultwarden/web-vault
WEB_VAULT_ENABLED=true
ADMIN_TOKEN=$__admin_token
DOMAIN=https://$__srvfqdn
WEBSOCKET_ENABLED=true
WEBSOCKET_ADDRESS=127.0.0.1
WEBSOCKET_PORT=$__wsport
ROCKET_ADDRESS=127.0.0.1
ROCKET_PORT=$__rkport
ROCKET_WORKERS=10
EOF
    cat > /etc/systemd/system/vaultwarden.service <<EOF
[Unit]
Description=Vaultwarden Server
Documentation=https://github.com/dani-garcia/vaultwarden
After=network.target $__std_add
Requires=$__std_add

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
    if [ $__dbtype == "sqlite" ]; then
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
