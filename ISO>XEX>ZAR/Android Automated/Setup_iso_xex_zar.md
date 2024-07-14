## Setting up ISO2XEX, XEX2ZAR and ISO2ZAR scripts on Termux

### This will require 1GB free storage on your device.

1. **Create Input Folders:**
   - In your download folder, create 2 folders, `ISO Input` and `XEX Input`.
   - Move your Xbox 360 ISO roms (loose or zipped) into the ISO Input folder or your XEX folders to XEX Input.

2. **Run Automated Setup Script:**
   - Open Termux and copy and paste the automated `setup_iso_xex_zar.sh` script into Termux.
   - Press enter to execute the script.

3. **Grant Storage Access:**
   - When prompted to allow storage access, please press "Allow" within 5 seconds.

4. **Installation Process:**
   - The setup process will take around 5-10 minutes to complete.

5. **Execute Conversion:**
   - Once installation finishes, log in to Ubuntu with:
     ```
     proot-distro login ubuntu
     ```
   - Type the required command:
     ```
     ./iso2xex.sh
     ./xex2zar.sh
     ./iso2zar.sh
     ```

6. **Conversion Completion:**
   - Allow the conversion to complete.
   - Your roms will be in new folders named either `XEX Output` or `ZAR Output` in your download path.

#### To convert roms in future just follow step 5 again.
