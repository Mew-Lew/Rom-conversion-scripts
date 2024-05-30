1. **Download Termux** from F-Droid.
2. Open the app and input:
   ```pkg update && pkg upgrade```
   Input 'Y' to accept at each prompt.
4. Once it's done, input:
   ```termux-setup-storage```
   Press allow to grant storage access.
5. After that, input:
   ```pkg install proot-distro```
   Input 'Y' to install.
6. Once installed, type:
   ```proot-distro install ubuntu```
   This will take a few minutes.
7. When it's done, input:
   ```proot-distro login ubuntu```
   You'll enter Ubuntu when you see `root@localhost` on your console.
8. Input:
   ```apt update && apt upgrade```
   Input 'Y' to update.
9. Then, input:
   ```apt install mame-tools ls unzip```
   Input 'Y' to install.
   Input your geographic area and time zone when prompted. For example, type 'Europe' and 'London'.

There are two bash scripts: one for CDs (`chdcreatecd.sh`) and one for DVDs (`chdcreatedvd.sh`).

Use the scripts as follows:

-**For PS2**:

Refer to the Redump database (http://redump.org/) to determine the original media type:

- CD: use `createcd`
- DVD: use `createdvd`

- **PSP**: `createdvd`
- **Dreamcast (GDI or BIN/CUE)**: `createcd`
- **PS1 (ISO or BIN/CUE)**: `createcd`
- **Sega Saturn (BIN/CUE)**: `createcd`
- **Sega CD (BIN/CUE)**: `createcd`
- **PC Engine/Turbo Grafx-CD (BIN/CUE)**: `createcd`

Ensure you have separate input/output paths for each script:

- `createcd` input
- `createcd` output
- `createdvd` input
- `createdvd` output

**Notes for GDI files**:
- Dreamcast GDI dumps include a GDI file plus raw and track files (e.g., track1, track2, etc.).
- For multiple GDI ROMs, keep them in individual folders or compress them as ZIP files.
- The script can unzip to a temporary folder, compress to CHD, and delete the temporary folder.

**For BIN/CUE files**:
- These can be loose as they share the same base name with different extensions.
- They can be inside a folder in the input path.
- They can be archived in .zip format.

**For ISO files**:
- These can be loose as they are a single file.
- They can be inside a folder in the input path.
- They can be archived in .zip format.

However both scripts can:
- Look inside folders in the input path.
- Unzip .zip archives to a temporary folder, compress to CHD, and delete the temporary folder.
- Process loose BIN/CUE and ISO files.

**Note**: Only .zip archives are supported.

**Note**: Depending on your phone this could be quite slow. For example, on my Pixel 7 it takes about 5 minutes to compress one 5GB rom. Your phone will also be very slow while it is running, this is normal, just put your phone down and let it run.
