#!/usr/bin/env bash
#-------------------------------------------------------
# Requirement:  Be the `root` user.
# Note:         `apt` and Systemd commonds are used.
#-------------------------------------------------------
# Function:     Install MySQL Server components 5.6.51
#               on amd64 architecture instance with
#               Debian version 10 (Buster) and above.
# Platform:     Debian 10 (Buster) and above, amd64
#
# Filename:     mysql-5.6.51_debian10-install.sh
# Revision:     1.2.10
# Date:         March 29, 2024
# Author:       Signaliks
# Email:        i@iks.moe
#-------------------------------------------------------

set -eo pipefail
trap 'rm -rf $__mysql_install_tmp_path' EXIT
stty erase ^?

__mysql_install_tmp_path="$(mktemp -d -t bash-private-XXXXXXXXXX)"
__mysql_archives_base_url="https://cdn.mysql.com/archives"
__mysql_install_major_minor_version="5.6"
__mysql_archives_extend_url="$__mysql_archives_base_url/mysql-$__mysql_install_major_minor_version"
__mysql_install_build_version="51"
__mysql_install_version="$__mysql_install_major_minor_version"."$__mysql_install_build_version"
__mysql_install_revision="1debian9"
__mysql_install_arch="amd64"

__mysql_install_pkgname_lcommon="mysql-common"_"$__mysql_install_version"-"$__mysql_install_revision"_"$__mysql_install_arch"."deb"
__mysql_install_pkgname_libmysqlclient18="libmysqlclient18"_"$__mysql_install_version"-"$__mysql_install_revision"_"$__mysql_install_arch"."deb"
__mysql_install_pkgname_communityclient="mysql-community-client"_"$__mysql_install_version"-"$__mysql_install_revision"_"$__mysql_install_arch"."deb"
__mysql_install_pkgname_client="mysql-client"_"$__mysql_install_version"-"$__mysql_install_revision"_"$__mysql_install_arch"."deb"
__mysql_install_pkgname_communityserver="mysql-community-server"_"$__mysql_install_version"-"$__mysql_install_revision"_"$__mysql_install_arch"."deb"
__mysql_install_pkgname_server="mysql-server"_"$__mysql_install_version"-"$__mysql_install_revision"_"$__mysql_install_arch"."deb"

apt update -y && apt install wget -y || exit 1

wget -P $__mysql_install_tmp_path $__mysql_archives_extend_url/$__mysql_install_pkgname_lcommon || exit 1
wget -P $__mysql_install_tmp_path $__mysql_archives_extend_url/$__mysql_install_pkgname_libmysqlclient18 || exit 1
wget -P $__mysql_install_tmp_path $__mysql_archives_extend_url/$__mysql_install_pkgname_communityclient || exit 1
wget -P $__mysql_install_tmp_path $__mysql_archives_extend_url/$__mysql_install_pkgname_client || exit 1
wget -P $__mysql_install_tmp_path $__mysql_archives_extend_url/$__mysql_install_pkgname_communityserver || exit 1
wget -P $__mysql_install_tmp_path $__mysql_archives_extend_url/$__mysql_install_pkgname_server || exit 1

apt install -y $__mysql_install_tmp_path/$__mysql_install_pkgname_lcommon $__mysql_install_tmp_path/$__mysql_install_pkgname_libmysqlclient18 $__mysql_install_tmp_path/$__mysql_install_pkgname_communityclient $__mysql_install_tmp_path/$__mysql_install_pkgname_client $__mysql_install_tmp_path/$__mysql_install_pkgname_communityserver $__mysql_install_tmp_path/$__mysql_install_pkgname_server || exit 1
systemctl enable mysql || exit 1

echo "Holding MySQL Server components." || exit 1
apt-mark hold mysql-common libmysqlclient18 mysql-community-client mysql-client mysql-community-server mysql-server || exit 1

echo "Installation completed!" || exit 1
exit 0
