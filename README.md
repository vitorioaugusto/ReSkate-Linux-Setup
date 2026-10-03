# ReSkate Linux Setup

**English** | [Português (Brasil)](README.pt-BR.md)

A convenient way to configure **Skate + ReSkate on Linux** using Wine, VKD3D-Proton and DXVK, with a simple launcher and built-in backup, repair and reinstall options.

> **Status:** developed and tested on Arch Linux/CachyOS with an NVIDIA RTX GPU.  
> The script is designed to automatically skip NVAPI/NGX/DLSS on AMD and Intel GPUs, but those configurations still need more community testing.

## What this project does

- creates a dedicated Wine prefix for ReSkate;
- applies the workaround required for `api-ms-win-core-debug-minidump-l1-1-0.dll`;
- installs **VKD3D-Proton 3.0.1** for D3D12;
- installs **DXVK 3.1** for DXGI;
- on NVIDIA RTX GPUs:
  - installs **DXVK-NVAPI 0.9.2**;
  - configures NVIDIA NGX;
  - enables DLSS Super Resolution;
- creates the `~/.local/bin/reskate` launcher;
- creates `.desktop` shortcuts;
- supports backup, repair, prefix reinstallation and launcher-only recreation.

## Requirements

You need to have **Skate installed through Steam** and the **ReSkate files already copied into the game directory**.

This project **does not distribute** files from Skate, ReSkate, NVIDIA NGX, DXVK, VKD3D-Proton or Wine. Required components are obtained from the local system or their official upstream projects during setup.

### Arch / CachyOS / Manjaro

The script can automatically install several common dependencies through `pacman`.

### Other distributions

Before running the setup, make sure you have:

- Wine or Wine-Staging 64-bit;
- `curl`;
- `tar`;
- `zstd`;
- the 64-bit and 32-bit Vulkan driver for your GPU.

Automatic system package installation is currently implemented only for Arch-based distributions.

## Usage

Run the setup script directly:

```bash
bash scripts/reskate-setup.sh
```

With no arguments, it first opens an interactive menu:

```text
1) Install / repair the configuration
2) Reinstall the Wine prefix from scratch
3) Create a backup only
4) Recreate only the launcher and shortcuts
5) Exit
```

You can also call each mode directly:

```bash
bash scripts/reskate-setup.sh --backup-only
bash scripts/reskate-setup.sh --repair
bash scripts/reskate-setup.sh --reinstall
bash scripts/reskate-setup.sh --launcher-only
```

> Note: the current interactive script UI is still in Portuguese. Documentation is available in both English and Brazilian Portuguese.

### Safety

If a ReSkate Wine prefix already exists, repair and reinstall operations create a backup before making changes.

Backups are stored by default in:

```text
~/ReSkate-backups/
```

The `--launcher-only` mode does not modify Wine, DLLs, registry entries, VKD3D, DXVK or the Wine prefix.

## Building the launcher

The repository also includes a small C launcher that embeds the setup script into a single executable.

Build requirements:

- GCC;
- GNU Make;
- Python 3.

Regular build:

```bash
make
```

Static build:

```bash
make static
```

The output will be:

```text
ReSkate-Setup-x86_64
```

When launched by double-clicking, the executable tries to start the setup in a graphical terminal in this order: **Konsole**, **GNOME Terminal**, **XFCE Terminal**, then **xterm**.

The embedded script is extracted at runtime to:

```text
~/.cache/reskate-setup/reskate-setup-final-safe.sh
```

## Steam

After setup is complete, you can add the following file as a non-Steam game:

```text
~/.local/bin/reskate
```

Do not force Proton/Steam Play on that shortcut. The launcher already starts the configured Wine environment and prefix.

## NVIDIA, AMD and Intel

NVIDIA NVAPI/NGX/DLSS configuration is conditional.

On a supported NVIDIA RTX GPU with the proprietary driver active, the launcher enables the variables required by DXVK-NVAPI and DLSS.

On AMD and Intel GPUs, the script skips that section and keeps the graphics path based on VKD3D-Proton + DXVK. This behavior is intended to prevent NVIDIA-specific components from being applied to other GPUs, but additional testing on AMD and Intel hardware is welcome.

## Repository structure

```text
.
├── Makefile
├── README.md
├── README.pt-BR.md
├── LICENSE
├── scripts/
│   └── reskate-setup.sh
└── src/
    ├── embed.py
    └── launcher.c
```

## Contributing

Issues and pull requests are welcome, especially for:

- testing on additional Linux distributions;
- testing on AMD and Intel GPUs;
- improvements to Steam path detection;
- support for additional terminal emulators;
- package installation improvements outside the Arch ecosystem.

## Disclaimer

This is a community project and **is not affiliated with EA, Electronic Arts, ReSkate, NVIDIA, Valve, Wine, DXVK or VKD3D-Proton**.

All trademarks belong to their respective owners.

## License

This project is distributed under the [MIT License](LICENSE).
