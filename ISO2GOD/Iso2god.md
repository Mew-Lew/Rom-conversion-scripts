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
     apt install wget unzip cmake build-essential
     ```

4. **Download and Compile extract-xiso (See txt file for license):**
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
     
5. **Download and Compile ISO2GOD**
    - Type these commands in Termux, one by one:
     ```
     apt install pkg-config
     apt install libssl-dev
     curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
     rustup install nightly
     rustup override set nightly
     git clone https://github.com/Mew-Lew/iso2god-rs.git
     cd iso2god-rs
     cargo build --release
     ```

6. **Create and Edit Script:** (Choose the script you need)

   * **iso2god.sh:** This script performs a two-step conversion: Rewrites ISO file to compress then converts the rebuilt ISO to GOD.
   You are prompted to decide if you want to keep the rebuilt ISO file/s.

   - Type: `nano iso2god.sh`
   - Edit the script - Remember to adjust input and output paths.
   - To save and exit: press `CTRL+X`, then `Y`, and finally `Enter`.

7. **Make Script Executable:**
   - Type: `chmod +x iso2god.sh`

8. **Run the Script:**
   - Type: `./iso2god.sh`

**Remember:**

* Adjust the input and output paths within the script itself.

* When you want to run the script again in future
`proot-distro login ubuntu`
* Then run the script
`./iso2god.sh`
