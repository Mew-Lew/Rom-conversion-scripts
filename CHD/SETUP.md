**Script Conversion Tool (Use with Caution!)**

This tool lets you convert rom files to chd using Android or ChromeOS

**Before you start, you'll need:**

* ~1.5GB of free space on your phone

**Here's what to do:**

1. **Update package lists:**

   - Open Termux and type:
     ```pkg update && pkg upgrade```
   - **Press Y at every prompt**

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
     apt update && apt upgrade (Press Y at prompts)
     apt install mame-tools unzip
     ```
* **Input Y at every prompt and type your geographical information when prompted.**

4. **Create and Edit Script:** (Choose the script you need)

   * **chdcreatecd.sh:** Converts rom files directly to chd in cd format including zipped rom files. 
   * **chdcreatedvd.sh:** Converts rom files directly to chd in dvd format including zipped rom files.

   - Type: `nano scriptname.sh` (Replace `scriptname.sh` with the actual name)
   - Edit the script (instructions are at the top - remember to adjust input and output paths).
   - To save and exit: press `CTRL+X`, then `Y`, and finally `Enter`.

6. **Make Script Executable:**
   - Type: `chmod +x scriptname.sh`

7. **Run the Script:**
   - Type: `./scriptname.sh`

**Remember:**

* Replace `scriptname.sh` with the actual script name you want to run.
* Adjust the input and output paths within the script itself.

* When you want to run the script again in future
```proot-distro login ubuntu```
* Then run the script
```./scriptname.sh```
