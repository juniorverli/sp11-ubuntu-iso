#!/bin/sh
# Coleta estado do Bluetooth/WCN7850 para diagnostico pos-boot.
# Saida: /var/log/sp11-bt-diag.log
OUT=/var/log/sp11-bt-diag.log
{
  echo "== date =="; date
  echo "== lsmod =="; lsmod | grep -E 'hci_uart|btqca|pwrseq|bluetooth' || true
  echo "== serdev =="; ls -l /sys/bus/serial/devices/ 2>/dev/null || true
  for f in /sys/bus/serial/devices/*/modalias; do
    [ -e "$f" ] && echo "$f: $(cat "$f")"
  done
  echo "== bluetooth class =="; ls -l /sys/class/bluetooth/ 2>/dev/null || true
  echo "== rfkill =="; rfkill list 2>/dev/null || true
  echo "== dmesg =="; dmesg | grep -iE 'hci|qca|bluetooth|pwrseq|wcn|a98000|regulator' || true
  echo "== bluetoothctl =="; bluetoothctl list 2>/dev/null || true
} > "$OUT" 2>&1
