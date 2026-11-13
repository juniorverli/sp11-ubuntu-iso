#!/usr/bin/env bash
# Gera a ISO do Surface Pro 11 a partir de uma ISO base ja com Stubble+DTB.
#
# Uso:
#   BASE_ISO=~/Downloads/stonking-sp11-20261026-stubble-bt.iso \
#   DAILY_ISO=~/Downloads/stonking-desktop-arm64+x1e-20261026.iso \
#   scripts/build-bt-iso.sh
#
# Variaveis: BASE_ISO, DAILY_ISO, WORK, OUT
set -euo pipefail

BASE_ISO=${BASE_ISO:-$HOME/Downloads/stonking-sp11-20261026-stubble-bt.iso}
DAILY_ISO=${DAILY_ISO:-$HOME/Downloads/stonking-desktop-arm64+x1e-20261026.iso}
WORK=${WORK:-$HOME/sp11-work}
OUT=${OUT:-$WORK/stonking-sp11-stubble-bt-v3.iso}
REPO_DIR=$(cd "$(dirname "$0")/.." && pwd)

say() { printf '\n== %s ==\n' "$*"; }
need() { command -v "$1" >/dev/null 2>&1 || { echo "faltando: $1" >&2; exit 1; }; }

for t in xorriso unsquashfs mksquashfs sha256sum; do need "$t"; done
[ -f "$BASE_ISO" ] || { echo "BASE_ISO nao existe: $BASE_ISO" >&2; exit 1; }
[ -f "$DAILY_ISO" ] || { echo "DAILY_ISO nao existe (necessaria para o MBR/GPT hibrido): $DAILY_ISO" >&2; exit 1; }

rm -rf "$WORK"
mkdir -p "$WORK/tree" "$WORK/root"

say "extraindo ISO base"
xorriso -osirrox on -indev "$BASE_ISO" -extract / "$WORK/tree" >/dev/null

say "expandindo squashfs"
unsquashfs -d "$WORK/root" "$WORK/tree/casper/minimal.squashfs" >/dev/null

say "aplicando correcoes (fixes/rootfs)"
cp -a "$REPO_DIR/fixes/rootfs/." "$WORK/root/"

say "gerando squashfs"
mksquashfs "$WORK/root" "$WORK/minimal.squashfs" \
  -comp xz -b 131072 -processors "$(nproc)" -noappend >/dev/null

rm -f "$WORK/tree/casper/minimal.squashfs"
cp "$WORK/minimal.squashfs" "$WORK/tree/casper/minimal.squashfs"

say "montando ISO hibrida"
rm -f "$OUT"
xorriso -as mkisofs -V 'Ubuntu 26.10 arm64' --protective-msdos-label \
  -partition_cyl_align off -partition_offset 0 --mbr-force-bootable \
  -append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b "$WORK/tree/boot/efi-daily64.img" \
  -appended_part_as_gpt \
  -G --interval:local_fs:0s-15s:zero_mbrpt,zero_gpt:"$DAILY_ISO" \
  -c /boot/boot.cat -e /boot/efi-daily64.img -no-emul-boot -boot-load-size 0 \
  -o "$OUT" "$WORK/tree"

say "resultado"
ls -lh "$OUT"
sha256sum "$OUT"
