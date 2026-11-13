# DTB do Surface Pro 11 (Denali)

Base: `arch/arm64/boot/dts/qcom/x1p64100-microsoft-denali.dts`
(`hamoa.dtsi` + `x1-microsoft-denali.dtsi`) da árvore Ubuntu `linux-qcom-x1e-7.3.0`.

## Patches upstream aplicados (backlight)

| Commit | O que faz |
|---|---|
| `2a9f7dd32611` | eDP HPD: pinctrl do gpio119 em `&mdss_dp3` (a tela não acendia sem isso) |
| `28184d5a3698` | `pwm-backlight` + `regulator-edp-bl` (PMK8550 PWM gpio5, pmc8380_3 gpio4/gpio10, 5 ms) e painel sem `enable-gpios`/`pinctrl` conflitantes |

Aplicar os dois commits no source antes de compilar o DTB (buscar em
`git.kernel.org` pelo id).

## Extras deste projeto (`fixes/dts/sp11-extras.dtsi`)

- **CMA abaixo de 4 GiB** (Wi-Fi/ath12k):
  `alloc-ranges = <0x0 0x80000000 0x0 0x80000000>`.
- **PCIe4 = WCN7850**: `pinctrl-0 = <&pcie4_default>` e
  `reset-gpios = <&tlmm 146 GPIO_ACTIVE_LOW>`,
  `wake-gpios = <&tlmm 148 GPIO_ACTIVE_LOW>` no `&pcie4_port0`
  (mesmos gpios usados por outros X1E: ASUS Zenbook, HP EliteBook, Yoga Slim 7x).
- **BT_EN**: `bt-enable-gpios = <&tlmm 116 GPIO_ACTIVE_HIGH>` em `&uart14/bluetooth`.
  O `hci_qca` **não lê** essa propriedade (ele usa `enable-gpios`); o dono real do
  GPIO116 é o nó `wcn7850-pmu`. A propriedade é inofensiva e serve de documentação.

## Como compilar

```bash
scripts/build-dtb.sh /caminho/linux-qcom-x1e-7.3.0 fixes/dts/sp11-extras.dtsi denali-sp11.dtb
```

O script copia `x1p64100-microsoft-denali.dts` para uma variante `-sp11.dts`,
anexa o extras, e compila com `cpp` + `dtc` (sem build completo do kernel).

## Observações

- O DTB do Denali **não** existe no conjunto oficial da Ubuntu Concept (o Stubble
  original não casa o HWID do SP11) — por isso ele é embutido via `--devicetree-auto`.
- A tabela de HWIDs usada está em `fixes/hwids/denali-lcd.json`
  (`microsoft,denali-lcd`, painel LGD077b).
