#!/usr/bin/env bash
# Repackage do kernel OFICIAL da Ubuntu Concept dentro do Stubble, com o DTB
# do Surface Pro 11 e a tabela de HWIDs.
#
# Requer: stubble compilado (https://github.com/ubuntu/stubble -> stubblify
#         e stubble.efi), xorriso, objcopy.
#
# Uso:
#   DAILY_ISO=~/Downloads/stonking-desktop-arm64+x1e-20261026.iso \
#   STUBBLE_DIR=~/stubble \
#   DTB=~/sp11-work/denali-sp11.dtb \
#   scripts/build-stubble-vmlinuz.sh
#
# Saida: $WORK/vmlinuz-sp11.efi
set -euo pipefail

DAILY_ISO=${DAILY_ISO:-$HOME/Downloads/stonking-desktop-arm64+x1e-20261026.iso}
STUBBLE_DIR=${STUBBLE_DIR:-$HOME/stubble}
DTB=${DTB:?defina DTB=/caminho/denali-sp11.dtb}
UNAME=${UNAME:-7.3.0-24-qcom-x1e}
WORK=${WORK:-$HOME/sp11-work}
REPO_DIR=$(cd "$(dirname "$0")/.." && pwd)

for t in xorriso objcopy sha256sum; do
  command -v "$t" >/dev/null 2>&1 || { echo "faltando: $t" >&2; exit 1; }
done
[ -x "$STUBBLE_DIR/stubblify" ] || { echo "stubblify nao encontrado em $STUBBLE_DIR" >&2; exit 1; }
[ -f "$STUBBLE_DIR/stubble.efi" ] || { echo "stubble.efi nao encontrado em $STUBBLE_DIR" >&2; exit 1; }
[ -f "$DTB" ] || { echo "DTB nao encontrado: $DTB" >&2; exit 1; }

mkdir -p "$WORK"

echo "== extraindo vmlinuz oficial =="
xorriso -osirrox on -indev "$DAILY_ISO" -extract /casper/vmlinuz "$WORK/stock.efi" >/dev/null
objcopy --dump-section .linux="$WORK/stock-kernel.linux" "$WORK/stock.efi"
sha256sum "$WORK/stock-kernel.linux"
# Esperado: c312c461622a6861e22bdac81ea7f44803f98b605b99c3b7cef6c8ba23b89c6a

echo "== stubblify =="
"$STUBBLE_DIR/stubblify" build \
  --linux="$WORK/stock-kernel.linux" \
  --stub="$STUBBLE_DIR/stubble.efi" \
  --hwids="$REPO_DIR/fixes/hwids" \
  --devicetree-auto="$DTB" \
  --uname="$UNAME" \
  --output="$WORK/vmlinuz-sp11.efi"

file "$WORK/vmlinuz-sp11.efi"
echo "dtbauto: $(objdump -h "$WORK/vmlinuz-sp11.efi" | grep -c '\.dtbauto')"
ls -lh "$WORK/vmlinuz-sp11.efi"
