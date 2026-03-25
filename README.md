# systemd-ageless

An Arch Linux package for the [liberated systemd fork](https://github.com/Jeffrey-Sardina/systemd)

## Overview

This is essentially a fork of [the systemd package](https://gitlab.archlinux.org/archlinux/packaging/packages/systemd) in the Arch Linux core repository.

I included a script to pull from upstream, build the package and set up a local repository (build.sh).

## Quick start
I have created a pacman repo that provides the packages for the liberated systemd fork. You can add it to your `/etc/pacman.conf`, before the `[core]` repository (IMPORTANT!):

```
[systemd-ageless]
SigLevel = Optional TrustAll
Server = https://jarmoco.github.io/systemd-ageless-archpkg/pkg/
```

After adding the repository, you can update your system:

```bash
sudo pacman -Syu
```
You will be asked to confirm the replacement of the official systemd packages with the liberated ones.

Reboot after you are done.


## Building locally

```bash
./build.sh
```

This will:
1. Install devtools and namcap if missing
2. Clean corrupted systemd packages from cache
3. Build systemd in a clean chroot
4. Run namcap checks on PKGBUILD and packages
5. Copy packages to pkg/
6. Update the local repository database
7. Add the repository to /etc/pacman.conf
8. Print summary with next steps


## Repository Configuration

The build script should set this up automatically. You may need to adjust the `Server` path if you want to serve packages over network.

In case it didn't work, after running `build.sh`, add this to your `/etc/pacman.conf`, **before** the `[core]` repository:

```
[systemd-ageless]
SigLevel = Optional TrustAll
Server = http://localhost:8181
```

### Serving packages locally

To serve packages to other machines on your network:

```bash
./host-repo.sh
```

## Build Script Options

```bash
./build.sh -y    # Non-interactive mode (assume yes to all prompts)
./build.sh -h    # Show help
```

## Build Process

1. **check_deps** — Verifies `devtools` and `namcap` are installed, installs if needed
2. **handle_existing_systemd** — Warns if official systemd is installed (will be replaced)
3. **clear_bad_cache** — Removes corrupted systemd packages from pacman cache
4. **build_package** — Builds in clean chroot via `makechrootpkg`
5. **run_namcap** — Lints PKGBUILD and packages for issues
6. **update_srcinfo** — Generates `.SRCINFO` for AUR compatibility
7. **setup_pkg_dir** — Ensures `pkg/` directory exists
8. **cleanup_old_packages** — Copies new packages to `pkg/`
9. **cleanup_build_artifacts** — Removes `.pkg.tar.zst` and `.log` from root
10. **update_repo** — Updates repo database with `repo-add`
11. **add_pacman_repo** — Adds repo to `/etc/pacman.conf`
12. **print_summary** — Displays completion message and next steps

## Files

- `PKGBUILD` — Package build definition
- `build.sh` — Build automation script
- `pkg/` — Built packages and repository database
- `.SRCINFO` — Package metadata for AUR

## Uninstalling

```bash
# Remove the repo from pacman.conf
sudo sed -i '/^\[systemd-ageless\]/,/^$/d' /etc/pacman.conf

# Update package database, so the original packages from [core] are available again
sudo pacman -Sy

# Clean up build directory
rm -rf /var/lib/archbuild/extra-x86_64

# Update your system
sudo pacman -Su

# Reboot to load the new systemd
reboot
```

