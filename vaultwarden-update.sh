#!/usr/bin/env bash

# A shell script that can be used to automate updating Vaultwarden (direct deployment). Need to install curl, jq and uuid-runtime (uuidgen).

set -euo pipefail
trap 'rm -rf $__vw_temp_path; unset __vw_uuid_temp; unset __vw_temp_path; unset __vw_temp_out; unset __force_update' EXIT

__vw_uuid_temp="$(uuidgen | tr -d '-')"
__vw_temp_path="$(mktemp -d -t bash-private-$__vw_uuid_temp-$(basename $0)-XXXXXX)"
__vw_temp_out="$__vw_temp_path/output"
mkdir $__vw_temp_out

curl -s https://hub.docker.com/v2/repositories/vaultwarden/server/tags/alpine | jq -r '.images[] | select(.architecture == "amd64") | {architecture, digest}' > $__vw_temp_path/latest.json

__force_update=false

while getopts ":f" opt; do
  case $opt in
    f)
      __force_update=true
      ;;
  esac
done

versioncheck() {
    if [ ! -f /var/lib/vaultwarden/version.json ]; then
        echo "/var/lib/vaultwarden/version.json does not exist. To force an update, add the parameter -f . Exiting..."
        exit 1
    fi
    
    if diff $__vw_temp_path/latest.json /var/lib/vaultwarden/version.json; then
        echo "No update found yet. To force an update, add the parameter -f . Exiting..."
        exit 1
    else
        update
    fi
}

update() {
    curl -o $__vw_temp_path/docker-image-extract https://raw.githubusercontent.com/jjlin/docker-image-extract/main/docker-image-extract
    chmod +x $__vw_temp_path/docker-image-extract

    $__vw_temp_path/docker-image-extract -o $__vw_temp_out vaultwarden/server:alpine

    systemctl stop vaultwarden
    cp -f $__vw_temp_out/vaultwarden /usr/bin/vaultwarden
    chmod +x /usr/bin/vaultwarden
    rm -rf /var/lib/vaultwarden/web-vault
    cp -r $__vw_temp_out/web-vault/. /var/lib/vaultwarden/web-vault
    chown -R vaultwarden /var/lib/vaultwarden/web-vault
    systemctl start vaultwarden

    curl -s https://hub.docker.com/v2/repositories/vaultwarden/server/tags/alpine | jq -r '.images[] | select(.architecture == "amd64") | {architecture, digest}' > /var/lib/vaultwarden/version.json

    echo "Update completed!"
    exit 0
}
if ! $__force_update; then
    versioncheck
else
    update
fi
