# Bluetooth (WCN7850) — análise

## Arquitetura no kernel 7.3.0-24-qcom-x1e

O BT do WCN7850 é um **serdev UART** (`uart14` = `serial@a98000`, pinos qup1_se6:
CTS 56, RTS 57, TX 58, RX 59). O suporte QCA está **dentro de `hci_uart.ko`**
(`CONFIG_BT_HCIUART=m` + `CONFIG_BT_HCIUART_QCA=y`), e o power sequencing fica no
módulo `pwrseq_qcom_wcn.ko` (`CONFIG_POWER_SEQUENCING_QCOM_WCN=m`), que registra um
provider `pwrseq` casado ao nó `wcn7850-pmu`.

Cadeia correta:
1. `wcn7850-pmu` (DTB) → `pwrseq_qcom_wcn` registra o provider.
2. `hci_uart`/`hci_qca` pede `devm_pwrseq_get(serdev, "bluetooth")`.
3. O match do provider checa o consumidor pelo `vddaon-supply` →
   `vreg_pmu_aon_0p59` (grandparent = nó do PMU). Confere no nosso DTB.
4. Com o pwrseq, o driver liga reguladores + **BT_EN (GPIO116)** e segue para
   firmware (`qca/hmtnv20.bin` + `qca/hmtbtfw20.tlv`, presentes no squashfs).

## Onde quebra

O `hci_qca` tem um detalhe perigoso (`drivers/bluetooth/hci_qca.c`, probe do serdev):

```c
qcadev->bt_power->pwrseq = devm_pwrseq_get(&serdev->dev, "bluetooth");
if (IS_ERR(qcadev->bt_power->pwrseq))
        qcadev->bt_power->pwrseq = NULL;   /* engole -EPROBE_DEFER */
else
        break;                              /* caminho bom */
/* se chegou aqui: qca_init_regulators() no caminho legado */
```

Se o provider `pwrseq` **ainda não estiver registrado** quando o `hci_uart` proba
(ordem de carga de módulos), o `-EPROBE_DEFER` é descartado, o driver cai no caminho
legado e — como o nó `bluetooth` não tem `enable-gpios` (só `bt-enable-gpios`, que o
driver não lê) — `bt_en` fica `NULL`. Resultado: **o chip nunca é ligado** e o BT
não funciona, silenciosamente.

### Três estágios e o log que identifica cada um

| Estágio | Sintoma | Log |
|---|---|---|
| `hci_uart` não carrega / serdev não cria | nenhuma linha de BT | **nada** com `hci` |
| pwrseq não casou → caminho legado | hci0 pode existir, mas não sobe | `setting up wcn7850`, `Retry BT power ON`, `failed to open port`, `SSR or FW download time out` |
| pwrseq casou | funciona | `setting up wcn7850` + `hci0` em `bluetoothctl list` |

### Sobre `vddio1p2`

O `pwrseq_qcom_wcn` pede 7 supplies (`vdd`, `vddio`, `vddio1p2`, `vddaon`,
`vdddig`, `vddrfa1p2`, `vddrfa1p8`), mas o DTS do Denali (e o upstream) fornece 6 —
falta `vddio1p2`. **Não é a causa do BT não subir**: no boot por DT,
`regulator/core.c` trata supply ausente como *dummy* (`have_full_constraints()` =
`of_have_populated_dt()`), gerando apenas o aviso
`supply vddio1p2 not found, using dummy regulator`. O mesmo vale para
`qcom-pcie 1c00000 supply vdda/vddpe-3v3 not found`.

## Correção aplicada na `stubble-bt-v3`

Arquivos em `fixes/rootfs`:

- `/etc/modprobe.d/wcn-bt.conf`:
  `softdep hci_uart pre: pwrseq_qcom_wcn`
- `/etc/modules-load.d/wcn-bt.conf`: carrega `pwrseq_qcom_wcn` e depois `hci_uart`
  na ordem certa no boot.
- `/usr/local/bin/sp11-bt-diag.sh` + `sp11-bt-diag.service` (habilitado em
  `multi-user.target`): grava `/var/log/sp11-bt-diag.log` com `lsmod`, serdev,
  rfkill, `dmesg` filtrado e `bluetoothctl list`.

Nada de kernel, DTB ou initrd é alterado — a ISO v3 usa exatamente o kernel
oficial da `stubble-bt` (`.linux` `c312c461…`).

## Como diagnosticar após bootar

```bash
bluetoothctl list
cat /var/log/sp11-bt-diag.log
```

Se o BT subir, o log mostra `setting up wcn7850` e `hci0`. Caso contrário, o log
indica o estágio exato (tabela acima) e o próximo ajuste é feito a partir dele.

## Referências

- [LKML — Re: [PATCH v2] arm64: dts: qcom: x1e80100-qcp: Add WiFi/BT pwrseq](https://lists.openwall.net/linux-kernel/2025/02/11/1635)
- [spinics — Konrad Dybcio Reviewed-by](https://www.spinics.net/lists/devicetree/msg777854.html)
- [LKML — discussão original (out/2024)](https://lists.openwall.net/linux-kernel/2024/10/15/905)
