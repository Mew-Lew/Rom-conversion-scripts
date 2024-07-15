## Setting up CHDMAN on Termux

### This will require 1.5GB free storage on your device.

1. **Create Input Folders:**
   - In your download folder, create 2 folders `CD Input` and `DVD Input`
   - Move your roms (loose or zipped) into the required folder.

2. **Run Automated Setup Script:**
   - Open Termux and copy and paste the automated `CHD_setup.sh` script into Termux.
   - Press enter to execute the script.

3. **Grant Storage Access:**
   - When prompted to allow storage access, please press "Allow" within 5 seconds.

4. **Installation Process:**
   - The setup process will take around 5-10 minutes to complete.

5. **Execute CHD Conversion:**
   - Once installation finishes, log in to Ubuntu with:
     ```
     proot-distro login ubuntu
     ```
   - Type the required command:
     ```
     ./chdcreatecd.sh
     ./chdcreatedvd.sh
     ```
6. **Conversion Completion:**
   - Allow the conversion to complete.
   - Your CHD roms will be in a new folder named either `CD Output` or `DVD Output` in your download path.

#### To convert roms in future just follow step 5 again.
