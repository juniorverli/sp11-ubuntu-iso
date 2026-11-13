#!/bin/bash
set -e
SRC=/root/work/linux-src/linux-qcom-x1e-7.3.0
REPO=/root/work/stubble-repo
DAILY=/mnt/c/Users/junio/Downloads/stonking-desktop-arm64+x1e-20261026.iso
TREE=/root/work/ubuntu-daily-tree
LIVE=/root/work/live-root
EXT=/root/work/initrd-extract
ESP=/root/work/esp-daily64.img
KREL=7.3.0-24-qcom-x1e
SQ=/root/work/minimal-audio-bt-v2.squashfs
OUT=/root/work/stonking-sp11-20261026-stubble-audio-bt-v2.iso
DEST=/mnt/c/Users/junio/Downloads/stonking-sp11-20261026-stubble-audio-bt-v2.iso
LOG=/root/work/build-v2.log
exec > >(tee "$LOG") 2>&1

echo "=== 0. guard no source ==="
grep -n 'if (!apm)' "$SRC/sound/soc/qcom/qdsp6/q6apm.c" | head -3
grep -n 'if (!prm)' "$SRC/sound/soc/qcom/qdsp6/q6prm.c" | head -3

echo "=== 1. rebuild qdsp6 modules (config oficial, symvers oficial) ==="
cp /root/work/kernel-build/Module.symvers "$SRC/Module.symvers"
cd "$SRC"
make ARCH=arm64 KERNELRELEASE=$KREL -j4 M=sound/soc/qcom/qdsp6 2>&1 | tail -6
make ARCH=arm64 KERNELRELEASE=$KREL -j4 M=sound/soc/qcom 2>&1 | tail -6
modinfo sound/soc/qcom/qdsp6/snd-q6apm.ko | grep -E 'vermagic|depends'
modinfo sound/soc/qcom/snd-soc-x1e80100.ko | grep -E 'vermagic|depends'
sha256sum "$SRC/Module.symvers" /root/work/kernel-build/Module.symvers

echo "=== 2. instalar módulos no live root e initrd ==="
for R in "$LIVE" "$EXT"; do
  D=$R/usr/lib/modules/$KREL/kernel/sound/soc/qcom
  mkdir -p "$D/qdsp6"
  cp "$SRC/sound/soc/qcom/snd-soc-x1e80100.ko" "$D/"
  cp "$SRC/sound/soc/qcom/qdsp6/"*.ko "$D/qdsp6/"
  rm -f "$D/snd-soc-x1e80100.ko.zst" "$D/qdsp6/"*.ko.zst
  depmod -b "$R" $KREL
done
ls -l "$LIVE/usr/lib/modules/$KREL/kernel/sound/soc/qcom/qdsp6/q6prm.ko"

echo "=== 3. initrd ==="
cd "$EXT"
find . -print0 | cpio --null -o -H newc --quiet > /root/work/initrd-audio-bt-v2.cpio
ls -lh /root/work/initrd-audio-bt-v2.cpio
cp /root/work/initrd-audio-bt-v2.cpio "$TREE/casper/initrd"

echo "=== 4. squashfs ==="
rm -f "$SQ"
mksquashfs "$LIVE" "$SQ" -comp xz -b 131072 -processors 4 -noappend 2>&1 | tail -3
ls -lh "$SQ"
cp "$SQ" "$TREE/casper/minimal.squashfs"

echo "=== 5. kernel ORIGINAL Ubuntu + Stubble + DTB denali-bt ==="
xorriso -osirrox on -indev "$DAILY" -extract /casper/vmlinuz /root/work/stock-vmlinuz-outer.efi >/dev/null 2>&1
objcopy --dump-section .linux=/root/work/stock-kernel.linux /root/work/stock-vmlinuz-outer.efi
sha256sum /root/work/stock-kernel.linux
"$REPO/stubblify" build \
  --linux=/root/work/stock-kernel.linux \
  --stub="$REPO/stubble.efi" \
  --hwids=/root/work/denali-hwids/json \
  --devicetree-auto=/root/work/denali-backlight/denali-bt.dtb \
  --uname=$KREL \
  --output=/root/work/vmlinuz-denali-audio-bt-v2.efi 2>&1 | tail -4
file /root/work/vmlinuz-denali-audio-bt-v2.efi
cp /root/work/vmlinuz-denali-audio-bt-v2.efi "$TREE/casper/vmlinuz"

echo "=== 6. ISO ==="
cp "$ESP" "$TREE/boot/efi-daily64.img"
find "$TREE/boot" -maxdepth 1 -name 'efi-*.img' ! -name 'efi-daily64.img' -delete
rm -f "$OUT"
xorriso -as mkisofs -V 'Ubuntu 26.10 arm64' --protective-msdos-label \
  -partition_cyl_align off -partition_offset 0 --mbr-force-bootable \
  -append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b "$ESP" \
  -appended_part_as_gpt -G --interval:local_fs:0s-15s:zero_mbrpt,zero_gpt:"$DAILY" \
  -c /boot/boot.cat -e /boot/efi-daily64.img -no-emul-boot -boot-load-size 0 \
  -o "$OUT" "$TREE" 2>&1 | tail -4
ls -lh "$OUT"
sha256sum "$OUT"
cp "$OUT" "$DEST"
sha256sum "$DEST"
echo "BUILD_V2_DONE"
