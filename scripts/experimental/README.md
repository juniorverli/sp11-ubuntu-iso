# Experimental — áudio

Tentativa (parada) de habilitar o áudio do Surface Pro 11.

## O que foi tentado

- Kernel oficial `7.3.0-24-qcom-x1e` (sem recompilar).
- Módulos compilados contra o config/Symvers oficiais:
  `snd-soc-x1e80100.ko` e `sound/soc/qcom/qdsp6/*.ko`, com o backport upstream
  `ef7062864c05` (`ASoC: qcom: q6apm: Guard callbacks until probe data is ready`).
- Firmware Denali do DriverStore: `qcadsp8380.mbn`, `adsp_dtb.mbn`,
  `qccdsp8380.mbn`, `cdsp_dtb.mbn`; topologia
  `X1E80100-Microsoft-Surface-Pro-11-tplg.bin` e UCM
  `MICROSOFT-Surface-Pro-11.conf` (alsa-ucm-conf upstream).
- Resultado: `qcom-apm` GPR timeout (ADSP não responde); card não sobe.

## Situação

Parado a pedido. O `q6apm Guard` corrige callbacks, mas não resolve o timeout do
GPR. Peças não-upstream conhecidas: callback do `apr` (GPR) e patches de speaker
do SP11 — fora da regra "só upstream/Windows".

## Arquivo de referência

`build-audio-iso.sh` (nesta pasta): pipeline usado na v2 (kernel oficial +
módulos de áudio no initrd/squashfs). Ele pressupõe as árvores de build em
`$HOME/work/...`; ajuste os caminhos antes de usar.
