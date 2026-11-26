# systemd-ageless

An Arch Linux package for the [liberated systemd fork](https://github.com/Jeffrey-Sardina/systemd).

> **This repository is sunset.** It is no longer maintained, and the packages in
> `pkg/` are frozen at `261.1-1` (June 2026). If you use Arch Linux, install the
> [AUR packages](https://aur.archlinux.org/packages/systemd-liberated-git)
> instead — they build from upstream `main` and update with `yay -Syu`.
> The upstream project also lists the AUR package as the community option.
> The files here remain for reference only.

## I haven't installed this yet

Use the AUR. Install an AUR helper if needed, then build and install:

```bash
sudo pacman -S --needed yay          # or paru
yay -S systemd-liberated-git systemd-liberated-libs-git systemd-liberated-sysvcompat-git
```

Add `systemd-liberated-resolvconf-git`, `systemd-liberated-tests-git`, and
`systemd-liberated-ukify-git` only if you actually need those split packages.

If the build fails with `Program 'bindgen' not found`, install `rust-bindgen`
(`sudo pacman -S rust-bindgen`) and retry — the AUR PKGBUILD has not yet added it
as a build dependency.

Reboot, then check:

```bash
systemctl --version    # e.g. systemd 263.r<commit>-1-arch
```

## I already installed from this repository

**Before you start:** back up your data and have a bootable Arch USB ready.
Changing systemd can leave the machine unbootable;

1. Install the AUR replacements. This repository can stay enabled while building:

   ```bash
   sudo pacman -S --needed rust-bindgen   # needed by current upstream main
   yay -S systemd-liberated-git systemd-liberated-libs-git systemd-liberated-sysvcompat-git
   ```

   If yay fails with `removing systemd breaks dependency 'systemd=261.1' required
   by systemd-sysvcompat`, it installed the packages in the wrong order. Build all
   targets, then install all three tarballs in **one** transaction:

   ```bash
   cd ~/.cache/yay/systemd-liberated-git
   sudo pacman -U \
     systemd-liberated-libs-git-*.pkg.tar.zst \
     systemd-liberated-git-*.pkg.tar.zst \
     systemd-liberated-sysvcompat-git-*.pkg.tar.zst
   ```

   Answer yes to removing the old `systemd`, `systemd-libs`, and
   `systemd-sysvcompat`. If you had other split packages from this repository,
   install their `systemd-liberated-*-git` equivalents too.

2. Verify and rebuild the initramfs:

   ```bash
   pacman -Q | grep systemd
   systemctl --version
   sudo mkinitcpio -P
   ```

3. Disable this repository:

   ```bash
   sudo sed -i '/^\[systemd-ageless\]/,/^$/d' /etc/pacman.conf
   sudo pacman -Sy          # -Sy, not -Syu
   ```

4. **Reboot.** Then confirm:

   ```bash
   systemctl --version
   systemctl is-system-running
   systemctl --failed
   ```

   `systemd-networkd-wait-online.service` can delay startup on NetworkManager
   systems; if it does, disable it with
   `sudo systemctl disable --now systemd-networkd-wait-online.service`.

### Rollback

Re-add the `[systemd-ageless]` block to `/etc/pacman.conf`, then:

```bash
sudo pacman -Syy
sudo pacman -S systemd systemd-libs systemd-sysvcompat
sudo mkinitcpio -P
reboot
```

If pacman refuses to replace the AUR packages, remove them first:

```bash
sudo pacman -Rdd systemd-liberated-git systemd-liberated-libs-git systemd-liberated-sysvcompat-git
```
