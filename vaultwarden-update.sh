#!/usr/bin/env bash

# A shell script that can be used to automate updating Vaultwarden (direct deployment). Need to install curl, jq and uuid-runtime (uuidgen).

set -euo pipefail
trap 'rm -rf $vw_temp_path' EXIT

vw_uuid_temp="$(uuidgen | tr -d '-')"
vw_temp_path="$(mktemp -d -t bash-private-$vw_uuid_temp-$(basename $0)-XXXXXX)"
vw_temp_out="$vw_temp_path/output"
mkdir $vw_temp_out

curl -s https://hub.docker.com/v2/repositories/vaultwarden/server/tags/alpine | jq -r '.images[] | select(.architecture == "amd64") | {architecture, digest}' > $vw_temp_path/latest.json

force_update=false

while getopts ":f" opt; do
  case $opt in
    f)
      force_update=true
      ;;
  esac
done

versioncheck() {
    if [ ! -f /var/lib/vaultwarden/version.json ]; then
        echo "/var/lib/vaultwarden/version.json does not exist. To force an update, add the parameter -f . Exiting..."
        exit 1
    fi
    
    if diff $vw_temp_path/latest.json /var/lib/vaultwarden/version.json; then
        echo "No update found yet. To force an update, add the parameter -f . Exiting..."
        exit 1
    else
        update
    fi
}

update() {
    curl -o $vw_temp_path/docker-image-extract https://raw.githubusercontent.com/jjlin/docker-image-extract/main/docker-image-extract
    chmod +x $vw_temp_path/docker-image-extract

    $vw_temp_path/docker-image-extract -o $vw_temp_out vaultwarden/server:alpine

    systemctl stop vaultwarden
    cp -f $vw_temp_out/vaultwarden /usr/bin/vaultwarden
    chmod +x /usr/bin/vaultwarden
    rm -rf /var/lib/vaultwarden/web-vault
    cp -r $vw_temp_out/web-vault/. /var/lib/vaultwarden/web-vault
    chown -R vaultwarden /var/lib/vaultwarden/web-vault
    systemctl start vaultwarden

    curl -s https://hub.docker.com/v2/repositories/vaultwarden/server/tags/alpine | jq -r '.images[] | select(.architecture == "amd64") | {architecture, digest}' > /var/lib/vaultwarden/version.json

    echo "Update completed!"
    exit 0
}
if ! $force_update; then
    versioncheck
else
    update
fi
