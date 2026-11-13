# Como a ISO é montada

## Layout híbrido

- ESP FAT32 de **64 MiB** (`/boot/efi-daily64.img`), usada como imagem El Torito
  (`-e /boot/efi-daily64.img -no-emul-boot -boot-load-size 0`) e também como
  partição GPT apendada.
- GRUB direto (`BOOTAA64.EFI` = `GRUBAA64.EFI`) dentro da ESP.
- Catálogo de boot em `/boot/boot.cat`.
- `-G --interval:local_fs:0s-15s:zero_mbrpt,zero_gpt:<ISO original>` copia os
  primeiros setores (MBR/GPT híbrido) da ISO original — necessário para Rufus/Ventoy.

Comando usado (idêntico ao do gerador):

```bash
xorriso -as mkisofs -V 'Ubuntu 26.10 arm64' --protective-msdos-label \
  -partition_cyl_align off -partition_offset 0 --mbr-force-bootable \
  -append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b "$TREE/boot/efi-daily64.img" \
  -appended_part_as_gpt \
  -G --interval:local_fs:0s-15s:zero_mbrpt,zero_gpt:"$DAILY_ISO" \
  -c /boot/boot.cat -e /boot/efi-daily64.img -no-emul-boot -boot-load-size 0 \
  -o "$OUT" "$TREE"
```

## Kernel: usar o oficial, nunca recompilar

A ISO que boota usa o **kernel oficial** da Ubuntu Concept:
`.linux` = `c312c461622a6861e22bdac81ea7f44803f98b605b99c3b7cef6c8ba23b89c6a`
(18.186.752 bytes). O Stubble recebe esse zimg pronto:

```bash
xorriso -osirrox on -indev "$DAILY_ISO" -extract /casper/vmlinuz stock.efi
objcopy --dump-section .linux=stock-kernel.linux stock.efi
stubblify build --linux=stock-kernel.linux --stub=stubble.efi \
  --hwids=fixes/hwids --devicetree-auto=denali-sp11.dtb \
  --uname=7.3.0-24-qcom-x1e --output=vmlinuz-sp11.efi
```

Por que não recompilar: um kernel reconstruído com `CONFIG_EFI_ZBOOT=y` +
`olddefconfig` perdeu opções do config Ubuntu (`CONFIG_RUST`, `CONFIG_DRM_EXEC=y`,
`CONFIG_DRM_GPUVM=y`, `CONFIG_MODULE_SIG_ALL`, `CONFIG_DEBUG_INFO_BTF`) e resultou em
`err getting clks -517`, falha do `arm-smmu` e
`unable to find a medium containing a live file system`.

Módulos extras (áudio, ath12k) devem ser compilados **contra** o config/Symvers
oficiais, como módulos, e instalados no initrd/squashfs — sem tocar no `vmlinuz`.

## Pipeline do gerador (`scripts/build-bt-iso.sh`)

1. Extrai a ISO base (`stubble-bt`) inteira para `$WORK/tree`
   (inclui `/boot/efi-daily64.img`, `grub.cfg`, `casper/*`).
2. `unsquashfs` do `casper/minimal.squashfs`.
3. Copia `fixes/rootfs/.` para dentro do root (modprobe.d, modules-load.d, systemd).
4. `mksquashfs` (xz, 128 KiB) e substitui `casper/minimal.squashfs`.
5. Repack com `xorriso`, reaproveitando ESP, `grub.cfg` e o cabeçalho da ISO original.
6. Calcula SHA-256.

O `initrd`/`vmlinuz` da base são mantidos intactos.
