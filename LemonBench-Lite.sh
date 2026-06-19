#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# LemonBench Lite
# A reduced system, CPU, and disk benchmark derived from LemonBench.
#
# Original project:
#   LemonBench — A simple Linux Benchmark Toolkit
#   Copyright (c) 2023 LemonBench
#   Source: https://github.com/LemonBench/LemonBench
#
# Modified version:
#   Copyright (c) 2026 ChatGPT <chatgpt@openai.com>
#   Modified by ChatGPT on 2026-06-19.
#
# Changes from the original project:
#   - Removed media-unlock tests.
#   - Removed network speed tests.
#   - Removed traceroute tests.
#   - Removed report-upload functionality.
#   - Removed dependencies used only by those deleted modules.
#   - Retained system-information, Sysbench CPU, and FIO disk tests.
#   - Expanded mappings for cloud providers and virtualization platforms.
#   - Added a safe fallback for unknown systemd-detect-virt results.
#   - Simplified command-line options and Debian dependency handling.

set -o pipefail
export LC_ALL=C

VERSION="2026.06.19-lite"
PRESET=""
WORKDIR="${TMPDIR:-/tmp}/lemonbench-lite.$$"
DISK_TEST_DIR="${LEMONBENCH_DISK_DIR:-/tmp}"

C_RESET='\033[0m'; C_GREEN='\033[0;32m'; C_YELLOW='\033[0;33m'; C_RED='\033[0;31m'; C_CYAN='\033[0;36m'
info()  { printf "%b[Info]%b %s\n" "$C_GREEN" "$C_RESET" "$*"; }
warn()  { printf "%b[Warn]%b %s\n" "$C_YELLOW" "$C_RESET" "$*" >&2; }
fatal() { printf "%b[Error]%b %s\n" "$C_RED" "$C_RESET" "$*" >&2; exit 1; }
line()  { printf '%s\n' '------------------------------------------------------------'; }
item()  { printf ' %-24s %s\n' "$1" "$2"; }
have()  { command -v "$1" >/dev/null 2>&1; }
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT INT TERM

usage() {
  cat <<USAGE
LemonBench Lite ${VERSION}

Usage:
  bash LemonBench-Lite.sh --fast
  bash LemonBench-Lite.sh --full

Options:
  -f, --fast       Quick CPU and disk benchmark
  -F, --full       Longer CPU and disk benchmark
  -h, --help       Show this help

Environment:
  LEMONBENCH_DISK_DIR=/path   Directory used for the temporary FIO file
USAGE
}

parse_args() {
  while (($#)); do
    case "$1" in
      -f|--fast|fast) PRESET="fast" ;;
      -F|--full|full) PRESET="full" ;;
      -h|--help) usage; exit 0 ;;
      --) ;;
      *) fatal "Unknown parameter: $1" ;;
    esac
    shift
  done
  [[ -n "$PRESET" ]] || { usage; exit 1; }
}

install_dependencies() {
  local missing=()
  have lscpu || missing+=(util-linux)
  have systemd-detect-virt || missing+=(systemd)
  have sysbench || missing+=(sysbench)
  have fio || missing+=(fio)
  have awk || missing+=(gawk)
  have findmnt || missing+=(util-linux)

  ((${#missing[@]} == 0)) && return 0
  [[ $EUID -eq 0 ]] || fatal "Missing dependencies: ${missing[*]}. Run as root once to install them."
  have apt-get || fatal "Automatic dependency installation currently supports Debian/Ubuntu only."

  mapfile -t missing < <(printf '%s\n' "${missing[@]}" | awk '!seen[$0]++')
  info "Installing dependencies: ${missing[*]}"
  apt-get update -qq || fatal "apt-get update failed"
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${missing[@]}" \
    || fatal "Dependency installation failed"
}

human_bytes() {
  awk -v n="${1:-0}" 'BEGIN {
    split("B KiB MiB GiB TiB PiB",u," "); i=1;
    while (n>=1024 && i<6) {n/=1024; i++}
    if (i==1) printf "%.0f %s",n,u[i]; else printf "%.2f %s",n,u[i]
  }'
}

read_first() {
  local f
  for f in "$@"; do [[ -r "$f" ]] && { tr -d '\0' < "$f"; return 0; }; done
  return 1
}

normalize_virt() {
  case "$1" in
    none|'') echo "Dedicated" ;;
    kvm) echo "KVM" ;;
    qemu) echo "QEMU" ;;
    vmware) echo "VMware" ;;
    microsoft|hyperv) echo "Microsoft Hyper-V" ;;
    oracle) echo "Oracle VirtualBox" ;;
    xen) echo "Xen" ;;
    bochs) echo "Bochs" ;;
    uml) echo "User-mode Linux" ;;
    parallels) echo "Parallels" ;;
    bhyve) echo "bhyve" ;;
    qnx) echo "QNX Hypervisor" ;;
    acrn) echo "ACRN" ;;
    powervm) echo "IBM PowerVM" ;;
    zvm) echo "IBM z/VM" ;;
    prl-hyperv) echo "Parallels Hypervisor" ;;
    google) echo "Google Compute Engine" ;;
    amazon) echo "Amazon EC2 Nitro/Xen" ;;
    apple) echo "Apple Virtualization" ;;
    docker) echo "Docker" ;;
    podman) echo "Podman" ;;
    lxc) echo "LXC" ;;
    lxc-libvirt) echo "LXC (libvirt)" ;;
    systemd-nspawn) echo "systemd-nspawn" ;;
    openvz) echo "OpenVZ/Virtuozzo" ;;
    wsl) echo "Windows Subsystem for Linux" ;;
    proot) echo "proot" ;;
    pouch) echo "Pouch" ;;
    rkt) echo "rkt" ;;
    firejail) echo "Firejail" ;;
    *) echo "Virtualized ($1)" ;;
  esac
}

detect_cloud_vendor() {
  local product vendor board bios text
  product="$(read_first /sys/class/dmi/id/product_name 2>/dev/null || true)"
  vendor="$(read_first /sys/class/dmi/id/sys_vendor 2>/dev/null || true)"
  board="$(read_first /sys/class/dmi/id/board_vendor 2>/dev/null || true)"
  bios="$(read_first /sys/class/dmi/id/bios_vendor 2>/dev/null || true)"
  text="${product} ${vendor} ${board} ${bios}"

  case "$text" in
    *Google*|*Google\ Compute\ Engine*) echo "Google Cloud Platform" ;;
    *Amazon\ EC2*|*Amazon*) echo "Amazon Web Services" ;;
    *Microsoft\ Corporation*|*Virtual\ Machine*)
      [[ -r /sys/class/dmi/id/chassis_asset_tag ]] && grep -qi '7783-7084-3265-9085-8269-3286-77' /sys/class/dmi/id/chassis_asset_tag \
        && echo "Microsoft Azure" || echo "Microsoft Hyper-V/Azure"
      ;;
    *Alibaba*|*Aliyun*) echo "Alibaba Cloud" ;;
    *Tencent*) echo "Tencent Cloud" ;;
    *Huawei*) echo "Huawei Cloud" ;;
    *OpenStack*) echo "OpenStack" ;;
    *DigitalOcean*) echo "DigitalOcean" ;;
    *Hetzner*) echo "Hetzner Cloud" ;;
    *OVH*) echo "OVHcloud" ;;
    *Scaleway*) echo "Scaleway" ;;
    *Oracle*) echo "Oracle Cloud/VirtualBox" ;;
    *Vultr*) echo "Vultr" ;;
    *Linode*|*Akamai*) echo "Akamai Connected Cloud (Linode)" ;;
    *VMware*) echo "VMware" ;;
    *QEMU*|*KVM*) echo "Generic KVM/QEMU" ;;
    *) echo "Unknown" ;;
  esac
}

system_info() {
  local os kernel arch hostname uptime_s load cpu_model sockets cores threads mhz cache virt_raw virt cloud
  os="$(. /etc/os-release 2>/dev/null; printf '%s' "${PRETTY_NAME:-Unknown Linux}")"
  kernel="$(uname -r)"; arch="$(uname -m)"; hostname="$(hostname)"
  uptime_s="$(awk '{print int($1)}' /proc/uptime)"
  load="$(cut -d' ' -f1-3 /proc/loadavg)"
  cpu_model="$(lscpu | awk -F: '/Model name|型号名称/ {sub(/^[ \t]+/,"",$2); print $2; exit}')"
  [[ -n "$cpu_model" ]] || cpu_model="$(awk -F: '/model name|Hardware/ {sub(/^[ \t]+/,"",$2); print $2; exit}' /proc/cpuinfo)"
  sockets="$(lscpu -p=SOCKET 2>/dev/null | awk -F, '!/^#/ {a[$1]=1} END{print length(a)}')"
  cores="$(lscpu -p=SOCKET,CORE 2>/dev/null | awk -F, '!/^#/ {a[$1 FS $2]=1} END{print length(a)}')"
  threads="$(getconf _NPROCESSORS_ONLN 2>/dev/null || nproc)"
  mhz="$(awk -F: '/cpu MHz/ {gsub(/^[ \t]+/,"",$2); printf "%.0f MHz",$2; exit}' /proc/cpuinfo)"
  cache="$(lscpu | awk -F: '/L3 cache/ {gsub(/^[ \t]+/,"",$2); print $2; exit}')"
  virt_raw="$(systemd-detect-virt 2>/dev/null || true)"
  virt="$(normalize_virt "$virt_raw")"
  cloud="$(detect_cloud_vendor)"

  local mt ma st sf root_total root_used root_avail root_fs root_dev
  mt=$(awk '/MemTotal/ {print $2*1024}' /proc/meminfo); ma=$(awk '/MemAvailable/ {print $2*1024}' /proc/meminfo)
  st=$(awk '/SwapTotal/ {print $2*1024}' /proc/meminfo); sf=$(awk '/SwapFree/ {print $2*1024}' /proc/meminfo)
  read -r root_total root_used root_avail < <(df -B1 --output=size,used,avail / | tail -1)
  root_fs="$(findmnt -n -o FSTYPE /)"; root_dev="$(findmnt -n -o SOURCE /)"

  printf '%b' "$C_CYAN"; line; printf '%b' "$C_RESET"
  printf ' LemonBench Lite System Information\n'
  printf '%b' "$C_CYAN"; line; printf '%b' "$C_RESET"
  item "Version:" "$VERSION"
  item "Hostname:" "$hostname"
  item "Operating System:" "$os"
  item "Kernel:" "$kernel"
  item "Architecture:" "$arch"
  item "Uptime:" "${uptime_s}s"
  item "Load Average:" "$load"
  item "CPU Model:" "${cpu_model:-Unknown}"
  item "CPU Frequency:" "${mhz:-Unknown}"
  item "CPU Configuration:" "${sockets:-?} socket(s), ${cores:-?} core(s), ${threads:-?} thread(s)"
  item "L3 Cache:" "${cache:-Unknown}"
  item "Virtualization:" "$virt"
  item "Cloud Platform:" "$cloud"
  item "Memory Usage:" "$(human_bytes "$((mt-ma))") / $(human_bytes "$mt")"
  item "Swap Usage:" "$(human_bytes "$((st-sf))") / $(human_bytes "$st")"
  item "Root Device:" "$root_dev ($root_fs)"
  item "Disk Usage:" "$(human_bytes "$root_used") / $(human_bytes "$root_total")"
}

cpu_bench_one() {
  local threads=$1 seconds=$2 out score
  out=$(sysbench cpu --threads="$threads" --time="$seconds" --cpu-max-prime=10000 run 2>/dev/null) || return 1
  score=$(awk -F: '/events per second/ {gsub(/^[ \t]+/,"",$2); print $2}' <<<"$out")
  printf '%s' "${score:-N/A}"
}

cpu_benchmark() {
  local total half duration runs i t sum score avg
  total="$(getconf _NPROCESSORS_ONLN 2>/dev/null || nproc)"; half=$((total / 2)); ((half < 1)) && half=1
  if [[ $PRESET == fast ]]; then duration=5; runs=1; else duration=15; runs=3; fi

  printf '\n%b' "$C_CYAN"; line; printf '%b CPU Performance Test (sysbench)\n' "$C_RESET"; line
  for t in 1 "$half" "$total"; do
    sum=0
    for ((i=1;i<=runs;i++)); do
      score="$(cpu_bench_one "$t" "$duration")" || { warn "sysbench failed"; score=0; }
      sum=$(awk -v a="$sum" -v b="$score" 'BEGIN{printf "%.4f",a+b}')
    done
    avg=$(awk -v a="$sum" -v n="$runs" 'BEGIN{printf "%.2f",a/n}')
    item "${t} Thread(s):" "${avg} events/sec"
    [[ $t -eq $total ]] && break
  done
}

fio_job() {
  local name=$1 rw=$2 bs=$3 runtime=$4 size=$5 file="$DISK_TEST_DIR/.lemonbench-lite.$$"
  local out bw iops lat
  out=$(fio --name="$name" --filename="$file" --size="$size" --direct=1 --ioengine=libaio \
    --iodepth=32 --numjobs=1 --rw="$rw" --bs="$bs" --time_based=1 --runtime="$runtime" \
    --group_reporting=1 --output-format=terse 2>/dev/null) || { rm -f "$file"; return 1; }
  rm -f "$file"
  # FIO terse v3: read BW KiB/s field 7, IOPS field 8; write BW field 48, IOPS field 49.
  if [[ $rw == *read ]]; then
    bw=$(awk -F';' '{print $7}' <<<"$out"); iops=$(awk -F';' '{print $8}' <<<"$out"); lat=$(awk -F';' '{print $40}' <<<"$out")
  else
    bw=$(awk -F';' '{print $48}' <<<"$out"); iops=$(awk -F';' '{print $49}' <<<"$out"); lat=$(awk -F';' '{print $81}' <<<"$out")
  fi
  awk -v bw="${bw:-0}" -v iops="${iops:-0}" -v lat="${lat:-0}" 'BEGIN {
    printf "%.2f MiB/s | %.2f IOPS", bw/1024, iops
    if (lat>0) printf " | %.2f ms", lat/1000000
  }'
}

disk_benchmark() {
  local runtime size result
  if [[ $PRESET == fast ]]; then runtime=5; size=256M; else runtime=15; size=1G; fi
  [[ -d $DISK_TEST_DIR && -w $DISK_TEST_DIR ]] || fatal "Disk test directory is not writable: $DISK_TEST_DIR"

  printf '\n%b' "$C_CYAN"; line; printf '%b Disk Performance Test (FIO, direct I/O)\n' "$C_RESET"; line
  for spec in "4K Random Read:randread:4k" "4K Random Write:randwrite:4k" "128K Sequential Read:read:128k" "128K Sequential Write:write:128k"; do
    IFS=: read -r label rw bs <<<"$spec"
    result="$(fio_job "lb-${rw}" "$rw" "$bs" "$runtime" "$size")" || result="Failed"
    item "$label" "$result"
  done
}

main() {
  parse_args "$@"
  mkdir -p "$WORKDIR"
  install_dependencies
  system_info
  cpu_benchmark
  disk_benchmark
  printf '\n'; line
  printf ' Completed. Network, route, media-unlock and upload modules are disabled.\n'
  line
}

main "$@"
