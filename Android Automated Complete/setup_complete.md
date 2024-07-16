## Setting up all conversion scripts on Termux

### This will require 6GB free storage on your device.

1. **Create Input Folders:**
   - In your download folder, create a folder called `Roms`.
   - In your `Roms` folder, create 5 folders:
     - CD Input
     - DVD Input
     - ISO2GOD Input
     - ISO Input
     - XEX Input
   - Move your rom/s (loose or zipped) into the required folder/s.

2. **Run Automated Setup Script:**
   - Open Termux and copy and paste the automated `setup_complete.sh` script into Termux.
   - Press enter to execute the script.

3. **Grant Storage Access:**
   - When prompted to allow storage access, please press "Allow" within 5 seconds.

4. **Installation Process:**
   - The setup process will take around 10-30 minutes to complete, depending on your download speed and mobile device.

5. **Execute Conversion:**
   - Once installation finishes, type the following command:
     ```
     ./convert.sh
     ```
   - You will be prompted to choose which conversion script you would like to run (1-6). Input the required number and press enter.

6. **Conversion Completion:**
   - Allow the conversion to complete.
   - Your roms will be in one of five new folders in your `Roms` folder in your download path.
     - CD Output
     - DVD Output
     - ISO2GOD Output
     - XEX Output
     - ZAR Output

#### To convert roms in future just follow step 5 again.
