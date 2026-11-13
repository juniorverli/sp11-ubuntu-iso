#!/usr/bin/env bash
# Compila o DTB do Surface Pro 11 (X1P64100) a partir da arvore Ubuntu
# linux-qcom-x1e, aplicando os extras do projeto.
#
# Premissa: os dois commits upstream de backlight ja aplicados no source
# (2a9f7dd32611 e 28184d5a3698) - ver docs/DTS.md.
#
# Uso:
#   scripts/build-dtb.sh /caminho/linux-qcom-x1e-7.3.0 \
#                        fixes/dts/sp11-extras.dtsi denali-sp11.dtb
set -euo pipefail

SRC=${1:?uso: build-dtb.sh <linux-src> <extras.dtsi> <saida.dtb>}
EXTRAS=${2:?informe o extras.dtsi}
OUT=${3:-denali-sp11.dtb}

QCOM="$SRC/arch/arm64/boot/dts/qcom"
BOARD="$QCOM/x1p64100-microsoft-denali.dts"
[ -f "$BOARD" ] || { echo "board dts nao encontrado: $BOARD" >&2; exit 1; }
[ -f "$EXTRAS" ] || { echo "extras nao encontrado: $EXTRAS" >&2; exit 1; }
command -v cpp >/dev/null || { echo "faltando: cpp" >&2; exit 1; }
command -v dtc >/dev/null || { echo "faltando: dtc (device-tree-compiler)" >&2; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

DST="$QCOM/x1p64100-microsoft-denali-sp11.dts"
cp "$BOARD" "$DST"
cat "$EXTRAS" >> "$DST"

cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp \
    -I "$SRC/arch/arm64/boot/dts" -I "$SRC/include" \
    "$DST" -o "$TMP/sp11.dts"

dtc -I dts -O dtb -o "$OUT" "$TMP/sp11.dts"

ls -lh "$OUT"
