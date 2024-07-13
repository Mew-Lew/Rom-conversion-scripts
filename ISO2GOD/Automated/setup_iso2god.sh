#!/bin/bash

echo "Updating Termux package lists..."
pkg update -y

echo "Upgrading Termux packages..."
yes | pkg upgrade

echo "Granting Termux Storage Access..."
termux-setup-storage

# Allow some time for the user to grant storage access
echo "Please allow storage access..."
sleep 5
# Simulate pressing Enter to continue the script
printf '\n' | read

echo "Installing proot-distro..."
pkg install proot-distro -y

echo "Setting up Ubuntu environment inside proot-distro..."
proot-distro install ubuntu

echo "Logging into the installed Ubuntu environment and running the rest of the setup script..."
proot-distro login ubuntu << 'EOF'

echo "Updating Ubuntu package lists..."
apt update -y

echo "Upgrading Ubuntu packages..."
apt upgrade -y

echo "Installing necessary tools in Ubuntu (wget, unzip, cmake, build-essential)..."
apt install wget unzip cmake git build-essential -y

echo "Downloading extract-xiso repository..."
wget https://github.com/XboxDev/extract-xiso/archive/refs/heads/master.zip

echo "Unzipping the downloaded extract-xiso repository..."
unzip master.zip

echo "Navigating into the extracted directory..."
cd extract-xiso-master

echo "Creating a build directory..."
mkdir build

echo "Navigating into the build directory..."
cd build

echo "Configuring cmake for extract-xiso..."
cmake ..

echo "Building extract-xiso..."
make

echo "Installing extract-xiso..."
make install

echo "Returning to the home directory..."
cd ~

echo "Installing pkg-config in Ubuntu..."
apt install pkg-config -y

echo "Installing libssl-dev in Ubuntu..."
apt install libssl-dev -y

echo "Downloading and installing rustup toolchain..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

echo "Installing nightly Rust toolchain..."
source $HOME/.cargo/env
rustup install nightly

echo "Setting nightly Rust toolchain as default..."
rustup override set nightly

echo "Cloning iso2god-rs repository from GitHub..."
git clone https://github.com/Mew-Lew/iso2god-rs.git

echo "Navigating into iso2god-rs directory..."
cd iso2god-rs

echo "Building ISO2GOD using cargo (Rust package manager)..."
cargo build --release

echo "Returning to the home directory..."
cd ~

echo "Creating iso2god.sh script with the provided content..."
cat << 'EOL' > iso2god.sh
#!/bin/bash

# This script utilizes extract-xiso downloaded from [https://github.com/XboxDev/extract-xiso/tree/master].
# The license terms are detailed in the extract-xiso-license.txt file included in this repository.

# Input and output paths
input_path="/storage/emulated/0/Download/ISO2GOD Input"
output_path="/storage/emulated/0/Download/ISO2GOD Output"

# Check if the output directory exists, if not, create it
mkdir -p "$output_path"

# Flag to track if any files were processed
files_processed=false

# Prompt to keep or delete rebuilt ISO files
echo -e "\e[32mWould you like to KEEP the rebuilt ISO files?\e[0m
\e[33m1) Yes\e[0m
\e[35m2) No\e[0m
\e[31m3) Cancel conversion\e[0m"

# Prompt for input
read -p $'Enter your choice (1-3): ' choice

# Validate input
while [[ "$choice" != "1" && "$choice" != "2" && "$choice" != "3" ]]; do
    echo -e "\e[31mInvalid input. Please enter '1', '2', or '3'.\e[0m"
    read -p $'Enter your choice (1-3): ' choice
done

# If chooses to cancel
if [ "$choice" == "3" ]; then
    echo -e "\e[31mConversion cancelled.\e[0m"
    exit 0
fi

# Function to rewrite ISO using extract-xiso
rewrite_iso() {
    local iso_file="$1"
    local file_name=$(basename -- "$iso_file")

    # Perform the rewrite
    extract-xiso -r "$iso_file" -d "$input_path"
    if [ $? -eq 0 ]; then
        local rewritten_iso="$input_path/$file_name"
        convert_to_god "$rewritten_iso"
    else
        echo -e "\e[31mFailed to rewrite ISO file $file_name.\e[0m"
    fi
}

# Function to convert rebuilt ISO to GOD
convert_to_god() {
    local rewritten_iso="$1"
    local file_name=$(basename -- "$rewritten_iso")

    echo "Converting rebuilt ISO file $file_name to GOD..."
    (cd && ./iso2god-rs/target/release/iso2god "$rewritten_iso" "$output_path")
    if [ $? -eq 0 ]; then
        echo -e "\e[32mGOD file for $file_name created successfully.\e[0m"
        # Delete rebuilt ISO if chose not to keep it
        if [ "$choice" == "2" ]; then
            rm -f "$rewritten_iso"
            echo -e "\e[32mRebuilt ISO file $file_name deleted.\e[0m"
        fi
    else
        echo -e "\e[31mFailed to convert $file_name to GOD.\e[0m"
    fi
}

# Loop through each ISO file in the input directory
for iso_file in "$input_path"/*.iso; do
    if [ -f "$iso_file" ]; then
        rewrite_iso "$iso_file"
        files_processed=true
    fi
done

# Loop through each ZIP file in the input directory
for zip_file in "$input_path"/*.zip; do
    if [ -f "$zip_file" ]; then
        # Create a temporary directory in the output path for extraction
        temp_dir="$output_path/temporary"
        mkdir -p "$temp_dir"

        # Unzip the file
        echo "Extracting ZIP file $zip_file..."
        unzip -q "$zip_file" -d "$temp_dir"

        # Find all ISO files in the unzipped content and rewrite them
        for iso_file in "$temp_dir"/*.iso; do
            if [ -f "$iso_file" ]; then
                rewrite_iso "$iso_file"
                files_processed=true
            fi
        done

        # Clean up temporary directory
        rm -rf "$temp_dir"
        echo -e "\e[32mTemporary folder for unzipped ISOs was deleted successfully.\e[0m"
    fi
done

# Check if any files were processed
if [ "$files_processed" = false ]; then
    echo -e "\e[31mNo ISO or ZIP files found to rewrite in the input directory.\e[0m"
else
    echo -e "\e[32mAll ISO files have been rebuilt and converted to GOD.\e[0m"
fi
EOL

echo "Making iso2god.sh script executable..."
chmod +x iso2god.sh

echo "Installation and setup complete. You can now run the iso2god.sh script by logging in to the Ubuntu environment with proot-distro login ubuntu and executing ./iso2god.sh."
EOF

echo "All steps completed. Please run the script again if you encounter any issues."
