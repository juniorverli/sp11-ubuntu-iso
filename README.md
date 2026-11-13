# Surface Pro 11 (X1P64100) — Ubuntu Concept 26.10 "Stonking"

ISO privada baseada na **Ubuntu Concept 26.10 arm64 (Stonking)**, mantendo o kernel oficial
Ubuntu, com o **Stubble** reaproveitado e o **DTB do Surface Pro 11 (LCD, X1P64100 "Denali")**
embutido. Inclui correções upstream para backlight, Wi-Fi e (em teste) Bluetooth.

> **Regra do projeto:** nada do Fedora. Apenas kernel/firmware Ubuntu, upstream
> (kernel.org, linux-firmware, alsa-ucm-conf) e firmware extraído do DriverStore do Windows.

## Status

| Item | Estado | Observação |
|---|---|---|
| Boot UEFI / Stubble | OK | kernel oficial `7.3.0-24-qcom-x1e` (`c312c461…`) |
| Tela / backlight | OK | commits upstream `2a9f7dd32611` + `28184d5a3698` |
| Wi-Fi (ath12k/WCN7850) | OK | board-2/hwids upstream + CMA/PCIe4 |
| Bluetooth | em investigação | `stubble-bt-v3` testa a ordem do `pwrseq_qcom_wcn` |
| Áudio (speakers/mic) | parado | `qcom-apm` GPR timeout; módulos testados na v2 |

## Estrutura

```
fixes/
  rootfs/                 arquivos copiados para dentro do squashfs
  dts/sp11-extras.dtsi    ajustes de DTB (CMA, PCIe4, BT_EN)
  hwids/denali-lcd.json   tabela de HWIDs para o Stubble
scripts/
  build-bt-iso.sh         gerador da ISO (base stubble-bt -> squashfs -> ISO)
  build-stubble-vmlinuz.sh  repackage do kernel oficial no Stubble + DTB
  build-dtb.sh            compila o DTB do Denali com os extras
  verify-iso.sh           verificação pós-build
  experimental/           tentativa de áudio (parada)
docs/
  STATUS.md               estado detalhado
  BLUETOOTH.md            análise do Bluetooth (onde quebra e por quê)
  ISO-BUILD.md            layout híbrido, xorriso, por que NÃO recompilar o kernel
  DTS.md                  patches de DTB/backlight usados
artifacts/SHA256SUMS      checksums das ISOs geradas
```

## Pré-requisitos

- Ubuntu arm64 (WSL serve) com: `xorriso`, `squashfs-tools`, `zstd`, `binutils`,
  `device-tree-compiler`, `cpio`, `git`.
- ISO base: `stonking-sp11-20261026-stubble-bt.iso` (boota, Wi-Fi + backlight).
- ISO original: `stonking-desktop-arm64+x1e-20261026.iso` (usada só para copiar o
  cabeçalho GPT/MBR híbrido com `-G --interval`).
- Para regerar o `vmlinuz`: [ubuntu/stubble](https://github.com/ubuntu/stubble) compilado
  (`stubblify` + `stubble.efi`).

## Gerar a ISO

```bash
BASE_ISO=~/Downloads/stonking-sp11-20261026-stubble-bt.iso \
DAILY_ISO=~/Downloads/stonking-desktop-arm64+x1e-20261026.iso \
scripts/build-bt-iso.sh
```

Saída em `$WORK` (padrão `~/sp11-work`) com SHA-256 impresso no final.

## Artefatos

Ver `artifacts/SHA256SUMS`. A ISO de referência que boota é a `stubble-bt`
(`4cc5744f…`); a `stubble-bt-v3` (`1d1294a6…`) adiciona a correção de ordem do
`pwrseq_qcom_wcn` e o diagnóstico de BT.
