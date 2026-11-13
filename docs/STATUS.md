# Estado do projeto

## Hardware

- Microsoft Surface Pro 11th Edition (LCD)
- SoC Snapdragon X Plus **X1P64100** ("Denali", família X1E80100/Hamoa)
- Wi-Fi/BT: Qualcomm **WCN7850** (PCIe4 para Wi-Fi, UART14 para BT)
- Base: Ubuntu Concept 26.10 "Stonking" arm64, kernel `7.3.0-24-qcom-x1e`

## O que funciona

- Boot UEFI via **Stubble** com o DTB `x1p64100-microsoft-denali.dtb` (LCD) embutido
  (`.dtbauto`) e tabela de HWIDs (`fixes/hwids/denali-lcd.json`).
- **Backlight**: commits upstream `2a9f7dd32611` (HPD/eDP pinctrl gpio119) e
  `28184d5a3698` (`pwm-backlight` + `regulator-edp-bl`).
- **Wi-Fi**: ath12k carrega; corrigido com board-2/hwids do linux-firmware upstream,
  CMA abaixo de 4 GiB e PERST/WAKE da PCIe4 (gpios 146/148).
- **ADSP/CDSP**: firmware Denali do DriverStore (`qcadsp8380.mbn`, `adsp_dtb.mbn`,
  `qccdsp8380.mbn`, `cdsp_dtb.mbn`) evita o erro do `qcom_pd_mapper`.
- Wi-Fi + backlight + boot confirmados em hardware.

## O que não funciona / em aberto

- **Bluetooth**: o WCN7850 não sobe. Análise completa em `BLUETOOTH.md`.
  A `stubble-bt-v3` força a ordem `pwrseq_qcom_wcn` → `hci_uart` e grava um log
  de diagnóstico em `/var/log/sp11-bt-diag.log`.
- **Áudio**: `qcom-apm` GPR timeout no ADSP. O caminho v2 (kernel oficial + módulos
  `snd-soc-x1e80100`/`qdsp6` com o backport `ef7062864c05`) está parado.
- **PCIe5** (`1c00000`): avisos de "supply vdda/vddpe-3v3 not found" são apenas
  *dummy regulators* (o DTB não habilita a pcie5; ruído benigno).
- `surface_serial_hub dropping unexpected command`: warning do SSAM
  (`ssh_request_layer.c`), benigno.
- `sssd` dependency failed: unit sem back-end de identidade na sessão live.
- `device descriptor read/64, error -100`: enumeração USB de algum dispositivo;
  não afeta o BT (que é UART).
- `out-of-tree module taints kernel`: esperado — o `ath12k` foi compilado fora da árvore.

## Versões de kernel

| Imagem | Kernel | Observação |
|---|---|---|
| Stonking (base) | 7.3.0-24-qcom-x1e | `.linux` `c312c461…`, o que boota |
| v2 (áudio) | 7.3.0-24 | mesmo kernel oficial; só módulos de áudio |
| áudio v1 | 7.3.0-24 recompilado | **não usar** — kernel diferente, não boota |

> Lição: **não recompilar o kernel** para trocar módulos. O kernel recompilado com
> `EFI_ZBOOT`/`olddefconfig` perdeu opções do config Ubuntu (`CONFIG_RUST`,
> `DRM_EXEC`, `DRM_GPUVM`, `DEBUG_INFO_BTF`…), gerando `-517` em clocks,
> falha do `arm-smmu` e "unable to find a medium containing a live file system".
