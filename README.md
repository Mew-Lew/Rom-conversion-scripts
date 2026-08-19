# Termux ROM Conversion Scripts

A collection of Bash scripts for converting and compressing ROMs on Android and ChromeOS using Termux and an Ubuntu `proot-distro` environment.

The installer sets up the required tools, creates the input and output folders in shared storage, and installs a menu-driven launcher for running conversions.

## Supported conversions

| Menu option | Conversion | Accepted input |
| --- | --- | --- |
| 1 | CD image to CHD | CUE, ISO, GDI or ZIP |
| 2 | DVD image to CHD | CUE, ISO or ZIP |
| 3 | Xbox ISO to extracted XEX folder | ISO or ZIP |
| 4 | Extracted XEX folder to ZAR | Folder |
| 5 | Xbox ISO to ZAR | ISO or ZIP |
| 6 | Xbox or Xbox 360 ISO to GOD | ISO or ZIP |

## Requirements

- An AArch64 Android or ChromeOS device
- [Termux](https://f-droid.org/packages/com.termux/) with storage permission
- An internet connection during installation
- Enough free storage for both the source files and converted output

The installer uses Ubuntu through `proot-distro`. Root access is not required.

## Installation

Open Termux and run:

```bash
pkg install -y curl && curl -fL --retry 3 https://raw.githubusercontent.com/Mew-Lew/Rom-conversion-scripts/v3.5.1/setup_complete_optimized.sh -o setup.sh && bash setup.sh
```

This downloads and runs the installer.

The setup menu has two options:

1. **Normal setup or repair** — installs or repairs the required tools without performing full Termux and Ubuntu package upgrades.
2. **Update and setup** — upgrades Termux and Ubuntu packages first, then installs or repairs the required tools.

For a first-time installation, use **Normal setup or repair**. Android will ask you to grant Termux access to shared storage during setup.

## Usage

Once setup is complete, open Termux and run:

```bash
./convert.sh
```

Select the conversion you want from the menu.

The launcher also includes options to repair the installed tools or update packages before running the repair process.

## Input and output folders

Setup creates the following folders under:

```text
/storage/emulated/0/Download/Roms/
```

| Conversion | Input folder | Output folder |
| --- | --- | --- |
| CD to CHD | `CD Input` | `CD Output` |
| DVD to CHD | `DVD Input` | `DVD Output` |
| ISO to XEX | `ISO Input` | `XEX Output` |
| XEX to ZAR | `XEX Input` | `ZAR Output` |
| ISO to ZAR | `ISO Input` | `ZAR Output` |
| ISO to GOD | `ISO2GOD Input` | `ISO2GOD Output` |

Place your source files in the appropriate input folder before running `./convert.sh`.

For XEX-to-ZAR conversion, each extracted game should be placed in its own directory:

```text
XEX Input/
└── Game Name/
    ├── default.xex
    └── ...
```

## ISO2GOD modes

When using ISO2GOD, you'll be asked to choose a mode for the current batch:

- **Untouched** — standard conversion without trimming.
- **Partial** — uses iso2god-rs native trimming (`--trim`) to reduce the resulting GOD container.
- **Remove all** — rebuilds each ISO with `extract-xiso` before converting it to GOD. Rebuilt ISOs are temporary and are automatically deleted after conversion.

The original ISO is restored after a rebuild, including if the process is interrupted. Remove all mode needs temporary free space at least equal to the source ISO size.

## Existing output handling

When output already exists, the script gives you these options:

1. **Skip** — leave the existing output untouched and move to the next item.
2. **Replace** — replace the existing output only after the new conversion completes successfully.
3. **Backup** — preserve the existing output as a timestamped backup before replacing it.
4. **Skip all existing** — skip every remaining item that already has output.
5. **Replace all existing** — replace every remaining existing output after each new conversion completes successfully.
6. **Cancel batch** — stop the current batch.

Conversions are written to a temporary staging directory first. Existing output is not replaced until the new conversion has completed successfully.

## ISO2GOD performance setting

ISO2GOD uses two workers by default. Increase the setting carefully on devices with enough memory, cooling, and free storage:

```bash
ISO2GOD_THREADS=4 ./convert.sh
```

`ISO2GOD_THREADS` controls ISO2GOD conversion workers.

## Download verification

The installer downloads each runtime script individually and verifies its SHA-256 checksum before installing it.

It also verifies the pinned ISO2GOD binary and the pinned `extract-xiso` source archive. If a download is incomplete, has been modified, or doesn't match the expected version, setup stops rather than installing the unverified file.

## Repository structure

```text
Rom-conversion-scripts/
├── common.sh
├── convert.sh
├── setup_complete_optimized.sh
├── CHD/
│   ├── chdcreatecd.sh
│   └── chdcreatedvd.sh
├── ISO2GOD/
│   └── Iso2god.sh
└── ISO-XEX-ZAR/
    ├── iso2xex/
    │   └── iso2xex.sh
    ├── iso2zar/
    │   └── iso2zar.sh
    └── xex2zar/
        └── xex2zar.sh
```

## Included tools

The setup process installs or downloads the following tools:

- [MAME CHDMAN](https://www.mamedev.org/) for CHD creation
- [XboxDev extract-xiso](https://github.com/XboxDev/extract-xiso) for extracting Xbox ISOs
- [iso2god-rs](https://github.com/iliazeus/iso2god-rs) for GOD conversion
- `zarchive-tools` for creating ZAR archives

These upstream tools remain subject to their respective licences.

## Legal notice

These scripts do not include games, ROMs, disc images or other copyrighted game data. Only use them with files that you are legally permitted to copy and convert.

## Licence

The scripts in this repository are released under the MIT Licence.
