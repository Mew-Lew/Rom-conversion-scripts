### Setting up ISO2GOD on Termux

## This will require 5GB free storage on your device.

1. **Create ISO2GOD Input Folder:**
   - In your download folder, create a folder called `ISO2GOD Input`.
   - Move your Xbox 360 ISO roms (loose or zipped) into the folder.

2. **Run Automated Setup Script:**
   - Open Termux and copy and paste the automated `setup_iso2god.sh` script into Termux.
   - Press enter to execute the script.

3. **Grant Storage Access:**
   - When prompted to allow storage access, please press "Allow" within 5 seconds.

4. **Installation Process:**
   - The setup process will take around 5-10 minutes to complete.

5. **Execute ISO2GOD Conversion:**
   - Once installation finishes, log in to Ubuntu with:
     ```
     proot-distro login ubuntu
     ```
   - Type the following command:
     ```
     ./iso2god.sh
     ```
   - You will be prompted to choose whether to keep the rebuilt ISO.

6. **Conversion Completion:**
   - Allow the conversion to complete.
   - Your GOD roms will be in a new folder named `ISO2GOD Output` in your download path.
