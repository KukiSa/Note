#!/usr/bin/env bash
#-------------------------------------------------------
# Requirement:  `root` user and `wget`.
# Note:         Content can become outdated at any time.
#-------------------------------------------------------
# Function:     
# Platform:     Linux, amd64
# Filename:     NextTrace-CN-return.sh
# Revision:     1.0.2
# Date:         June 13, 2024
# Author:       Signaliks
# Email:        i@iks.moe
#-------------------------------------------------------

set -eo pipefail
trap 'rm -rf $__nxtrace_return_tmp_path' EXIT
stty erase ^?

__nxtrace_return_tmp_path="$(mktemp -d -t bash-private-XXXXXXXXXX)"
__nxtrace_path="$__nxtrace_return_tmp_path/nexttrace"

wget -O "$__nxtrace_path" https://github.com/nxtrace/NTrace-core/releases/latest/download/nexttrace_linux_amd64

chmod +x $__nxtrace_path

echo "北京电信"
$__nxtrace_path -q 1 -m 30 -n -c -M 45.126.112.33

echo "北京移动"
$__nxtrace_path -q 1 -m 30 -n -c -M 183.242.65.12

echo "上海联通"
$__nxtrace_path -q 1 -m 30 -n -c -M 103.116.79.1

echo "上海电信"
$__nxtrace_path -q 1 -m 30 -n -c -M 210.5.157.1

echo "上海移动"
$__nxtrace_path -q 1 -m 30 -n -c -M 117.144.213.77

echo "广州联通"
$__nxtrace_path -q 1 -m 30 -n -c -M 210.21.4.130

echo "广州移动"
$__nxtrace_path -q 1 -m 30 -n -c -M 183.232.48.167

exit 0
