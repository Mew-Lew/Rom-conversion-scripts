**Script Conversion Tool (Use with Caution!)**

This tool lets you convert ISO files for Xbox 360 on your phone.

**Before you start, you'll need:**

* ~1GB of free space on your phone

**Here's what to do:**

1. **Update package lists:**

   - Open Termux and type:
     ```pkg update && pkg upgrade```
   - **Press Y at every prompt** that appears.

2. **Grant Termux Storage Access:**
This step allows Termux to access your phone's storage, which is necessary for the tool to function.
```termux-setup-storage```
* **When prompted, tap "Allow" to grant Termux storage access.**

3. **Install tools:**
   - Type these commands in Termux, one by one:
     ```
     pkg install proot-distro
     proot-distro install ubuntu
     proot-distro login ubuntu
     apt update && apt upgrade
     apt install wget unzip cmake zarchive-tools build-essential
     ```

4. **Download and Compile Tools:**
   - Type these commands in Termux, one by one:
     ```
     wget https://github.com/XboxDev/extract-xiso/archive/refs/heads/master.zip
     unzip master.zip
     cd extract-xiso-master
     mkdir build
     cd build
     cmake ..
     make
     make install
     cd
     ```

5. **Create and Edit Script:** (Choose the script you need)

   * **iso2xex.sh:** Converts ISO files directly to XEX format including zipped iso files. 
   * **xex2zar.sh:** Converts existing XEX folders to ZAR format.
   * **iso2zar.sh:** This script performs a two-step conversion: ISO to XEX, then XEX to ZAR also including zipped iso files.

   - Type: `nano scriptname.sh` (Replace `scriptname.sh` with the actual name)
   - Edit the script - Remember to adjust input and output paths.
   - To save and exit: press `CTRL+X`, then `Y`, and finally `Enter`.

6. **Make Script Executable:**
   - Type: `chmod +x scriptname.sh`

7. **Run the Script:**
   - Type: `./scriptname.sh`

**Remember:**

* Replace `scriptname.sh` with the actual script name you want to run.
* Adjust the input and output paths within the script itself.

* When you want to run the script again in future
`proot-distro login ubuntu`
* Then run the script
`./scriptname.sh`
