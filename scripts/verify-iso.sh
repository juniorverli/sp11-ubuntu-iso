#!/usr/bin/env bash
# Verifica uma ISO gerada: kernel oficial, Stubble/DTB e correcoes no squashfs.
#
# Uso: scripts/verify-iso.sh /caminho/stonking-sp11-...iso
set -euo pipefail

ISO=${1:?uso: verify-iso.sh <iso>}
KERNEL_SHA=c312c461622a6861e22bdac81ea7f44803f98b605b99c3b7cef6c8ba23b89c6a
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT

ls -lh "$ISO"
sha256sum "$ISO"

xorriso -osirrox on -indev "$ISO" \
  -extract /casper/vmlinuz "$W/vmlinuz" \
  -extract /casper/minimal.squashfs "$W/min.squashfs" >/dev/null 2>&1

objcopy --dump-section .linux="$W/linux.bin" "$W/vmlinuz"
got=$(sha256sum "$W/linux.bin" | cut -d' ' -f1)
echo "kernel .linux: $got"
[ "$got" = "$KERNEL_SHA" ] && echo "  OK (kernel oficial)" || { echo "  ERRO: kernel diferente do oficial"; exit 1; }

echo "dtbauto secoes: $(objdump -h "$W/vmlinuz" | grep -c '\.dtbauto')"
objcopy --dump-section .dtbauto="$W/dtb.bin" "$W/vmlinuz"
echo "bt-enable-gpios: $(strings -a "$W/dtb.bin" | grep -c 'bt-enable-gpios')"
echo "LCD model: $(strings -a "$W/dtb.bin" | grep -c 'Surface Pro 11th Edition (LCD)')"

echo "== squashfs =="
unsquashfs -ls "$W/min.squashfs" 2>/dev/null | grep -E \
  'etc/modprobe.d/wcn-bt.conf|etc/modules-load.d/wcn-bt.conf|sp11-bt-diag' | head
