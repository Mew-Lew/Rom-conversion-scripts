#!/bin/bash

echo -e "\e[32mUpdating Termux package lists...\e[0m"
pkg update -y

echo -e "\e[32mUpgrading Termux packages...\e[0m"
yes | pkg upgrade

echo -e "\e[32mGranting Termux Storage Access...\e[0m"
termux-setup-storage

# Allow some time for the user to grant storage access
echo -e "\e[32mPlease allow storage access...\e[0m"
sleep 5
# Simulate pressing Enter to continue the script
printf '\n' | read

echo -e "\e[32mInstalling proot-distro...\e[0m"
pkg install proot-distro -y

echo -e "\e[32mSetting up Ubuntu environment inside proot-distro...\e[0m"
proot-distro install ubuntu

echo -e "\e[32mLogging into the installed Ubuntu environment and running the rest of the setup script...\e[0m"
proot-distro login ubuntu << 'EOF'

echo -e "\e[32mUpdating Ubuntu package lists...\e[0m"
apt update -y

echo -e "\e[32mUpgrading Ubuntu packages...\e[0m"
apt upgrade -y

echo -e "\e[32mInstalling necessary tools in Ubuntu...\e[0m"
apt install wget unzip cmake git build-essential zarchive-tools -y

DEBIAN_FRONTEND=noninteractive apt install mame-tools -y

apt install pkg-config -y

apt install libssl-dev -y

echo -e "\e[32mDownloading extract-xiso source code from GitHub...\e[0m"
wget https://github.com/XboxDev/extract-xiso/archive/refs/heads/master.zip

echo -e "\e[32mUnzipping the downloaded file...\e[0m"
unzip master.zip

echo -e "\e[32mNavigating to the source directory...\e[0m"
cd extract-xiso-master

echo -e "\e[32mCreating a build directory and navigating to it...\e[0m"
mkdir build
cd build

echo -e "\e[32mConfiguring the project...\e[0m"
cmake ..

echo -e "\e[32mCompiling the project...\e[0m"
make

echo -e "\e[32mInstalling the compiled project...\e[0m"
make install

echo -e "\e[32mReturning to the home directory...\e[0m"
cd

echo -e "\e[32mDownloading and installing rustup toolchain...\e[0m"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

echo -e "\e[32mInstalling nightly Rust toolchain...\e[0m"
source $HOME/.cargo/env
rustup install nightly

echo -e "\e[32mSetting nightly Rust toolchain as default...\e[0m"
rustup override set nightly

echo -e "\e[32mCloning iso2god-rs repository from GitHub...\e[0m"
git clone https://github.com/Mew-Lew/iso2god-rs.git

echo -e "\e[32mNavigating into iso2god-rs directory...\e[0m"
cd iso2god-rs

echo -e "\e[32mBuilding ISO2GOD using cargo (Rust package manager)...\e[0m"
cargo build --release

echo -e "\e[32mReturning to the home directory...\e[0m"
cd ~

echo -e "\e[32mCreating iso2xex.sh script...\e[0m"
mkdir -p "rom scripts"
cat << 'EOT' > "rom scripts/iso2xex.sh"
#!/bin/bash

input_path="/storage/emulated/0/Download/Roms/ISO Input"
output_path="/storage/emulated/0/Download/Roms/XEX Output"

mkdir -p "$output_path"

files_processed=false

convert_iso_to_xex() {
    local iso_file="$1"
    local file_name=$(basename -- "$iso_file")
    local file_name_without_extension="${file_name%.*}"
    local iso_output_dir="$output_path/$file_name_without_extension"
    mkdir -p "$iso_output_dir"
    echo -e "\e[32mCreating XEX file for $file_name...\e[0m"
    extract-xiso -x "$iso_file" -d "$iso_output_dir"
}

for iso_file in "$input_path"/*.iso; do
    if [ -f "$iso_file" ]; then
        convert_iso_to_xex "$iso_file"
        files_processed=true
    fi
done

for zip_file in "$input_path"/*.zip; do
    if [ -f "$zip_file" ]; then
        temp_dir="$output_path/temporary"
        mkdir -p "$temp_dir"
        echo -e "\e[32mExtracting ZIP file $zip_file...\e[0m"
        unzip -q "$zip_file" -d "$temp_dir"
        for iso_file in "$temp_dir"/*.iso; do
            if [ -f "$iso_file" ]; then
                convert_iso_to_xex "$iso_file"
                files_processed=true
            fi
        done
        rm -rf "$temp_dir"
        echo -e "\e[32mTemporary folder for unzipped ISOs was deleted successfully.\e[0m"
    fi
done

if [ "$files_processed" = false ]; then
    echo -e "\e[31mNo ISO or ZIP files found to convert in the input directory.\e[0m"
else
    echo -e "\e[32mAll ISO files have been processed.\e[0m"
fi
EOT

chmod +x "rom scripts/iso2xex.sh"

echo -e "\e[32mCreating iso2zar.sh script...\e[0m"
cat << 'EOT' > "rom scripts/iso2zar.sh"
#!/bin/bash

input_path="/storage/emulated/0/Download/Roms/ISO Input"
xex_output_path="/storage/emulated/0/Download/Roms/XEX Output"
zar_output_path="/storage/emulated/0/Download/Roms/ZAR Output"

mkdir -p "$xex_output_path" "$zar_output_path"

convert_iso_to_xex() {
    local iso_file="$1"
    local temp_dir="$2"
    local file_name=$(basename -- "$iso_file")
    local file_name_without_extension="${file_name%.*}"
    local xex_output_dir="$xex_output_path/$file_name_without_extension"
    mkdir -p "$xex_output_dir"
    echo -e "\e[32mCreating XEX file for $file_name...\e[0m"
    if ! extract-xiso -x "$iso_file" -d "$xex_output_dir"; then
        echo -e "\e[31mFailed to create XEX file for $file_name.\e[0m"
        return 1
    fi
    if [ -d "$temp_dir" ]; then
        rm -rf "$temp_dir"
        echo -e "\e[32mTemporary ISO directory $temp_dir deleted after extracting XEX.\e[0m"
    fi
    convert_xex_to_zar "$xex_output_dir"
}

convert_xex_to_zar() {
    local xex_folder="$1"
    local folder_name=$(basename -- "$xex_folder")
    local zar_file="$zar_output_path/$folder_name.zar"
    if [ -f "$zar_file" ]; then
        echo -e "\e[33mThe output file $zar_file already exists. Removing it.\e[0m"
        rm -f "$zar_file"
    fi
    echo -e "\e[32mCreating ZAR file for $folder_name...\e[0m"
    if ! zarchive "$xex_folder" "$zar_file"; then
        echo -e "\e[31mFailed to create ZAR file for $folder_name.\e[0m"
        return 1
    fi
    echo -e "\e[32mZAR file $zar_file created successfully.\e[0m"
    rm -rf "$xex_folder"
    echo -e "\e[32mXEX folder $folder_name deleted after conversion to ZAR.\e[0m"
}

if [ ! -d "$input_path" ]; then
    echo -e "\e[31mInput path $input_path does not exist.\e[0m"
    exit 1
elif [ -z "$(ls -A "$input_path")" ]; then
    echo -e "\e[31mInput path $input_path is empty.\e[0m"
    exit 1
fi

iso_files_found=false
for iso_file in "$input_path"/*.iso; do
    if [ -f "$iso_file" ]; then
        iso_files_found=true
        echo -e "\e[32mProcessing ISO file: $iso_file\e[0m"
        convert_iso_to_xex "$iso_file" ""
    fi
done

zip_files_found=false
for zip_file in "$input_path"/*.zip; do
    if [ -f "$zip_file" ]; then
        zip_files_found=true
        temp_dir="$xex_output_path/temporary_$(basename -- "$zip_file" .zip)"
        mkdir -p "$temp_dir"
        echo -e "\e[32mExtracting ZIP file $zip_file...\e[0m"
        if unzip -q "$zip_file" -d "$temp_dir"; then
            for iso_file in "$temp_dir"/*.iso; do
                if [ -f "$iso_file" ]; then
                    convert_iso_to_xex "$iso_file" "$temp_dir"
                fi
            done
        else
            echo -e "\e[31mFailed to extract ZIP file $zip_file.\e[0m"
            rm -rf "$temp_dir"
            echo -e "\e[33mTemporary directory $temp_dir deleted due to extraction failure.\e[0m"
        fi
    fi
done

if [ "$iso_files_found" = false ] && [ "$zip_files_found" = false ]; then
    echo -e "\e[33mNo ISO or ZIP files found in $input_path.\e[0m"
fi

echo -e "\e[32mProcessing completed.\e[0m"
EOT

chmod +x "rom scripts/iso2zar.sh"

echo -e "\e[32mCreating xex2zar.sh script...\e[0m"
cat << 'EOT' > "rom scripts/xex2zar.sh"
#!/bin/bash

input_path="/storage/emulated/0/Download/Roms/XEX Input"
output_path="/storage/emulated/0/Download/Roms/ZAR Output"

if [ ! -d "$input_path" ]; then
    echo -e "\e[31mError: Input path does not exist\e[0m"
    exit 1
fi

if [ ! -d "$output_path" ]; then
    mkdir -p "$output_path"
fi

for folder in "$input_path"/*; do
    if [ -d "$folder" ]; then
        echo -e "\e[32mConverting folder: $(basename "$folder")\e[0m"
        zarchive "$folder" "$output_path/$(basename "$folder").zar"
        if [ $? -eq 0 ]; then
            echo -e "\e[32mSuccessfully converted $(basename "$folder") to zar file\e[0m"
        else
            echo -e "\e[31mError: Failed to convert $(basename "$folder")\e[0m"
        fi
    fi
done

if [ -z "$(ls -A "$input_path")" ]; then
    echo -e "\e[33mNothing to convert in the input path\e[0m"
fi
EOT

chmod +x "rom scripts/xex2zar.sh"

echo -e "\e[32mCreating iso2god.sh script...\e[0m"
cat << 'EOT' > "rom scripts/iso2god.sh"
#!/bin/bash

# This script utilizes extract-xiso downloaded from [https://github.com/XboxDev/extract-xiso/tree/master].
# The license terms are detailed in the extract-xiso-license.txt file included in this repository.

# Input and output paths
input_path="/storage/emulated/0/Download/Roms/ISO2GOD Input"
output_path="/storage/emulated/0/Download/Roms/ISO2GOD Output"

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

    echo -e "\e[32mConverting rebuilt ISO file $file_name to GOD...\e[0m"
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
        echo -e "\e[32mExtracting ZIP file $zip_file...\e[0m"
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
    echo -e "\e[33mNo ISO or ZIP files found to rewrite in the input directory.\e[0m"
else
    echo -e "\e[32mAll ISO files have been rebuilt and converted to GOD.\e[0m"
fi
EOT

chmod +x "rom scripts/iso2god.sh"

echo -e "\e[32mCreating chdcreatecd.sh script...\e[0m"
cat << 'EOT' > "rom scripts/chdcreatecd.sh"
#!/bin/bash

# Directory containing input files for createcd (BIN/CUE, ISO, and GDI)
INPUT_DIR="/storage/emulated/0/Download/Roms/CD Input"
# Output directory for CHD files
OUTPUT_DIR="/storage/emulated/0/Download/Roms/CD Output"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Enable nullglob and globstar to handle cases with no files found and to support recursive globbing
shopt -s nullglob globstar

# Function to process CUE files
process_cue_files() {
  for cue_file in "$1"/**/*.cue; do
    if [ -e "$cue_file" ]; then
      base_name=$(basename "$cue_file" .cue)
      chd_file="$OUTPUT_DIR/$base_name.chd"
      echo -e "\e[32mProcessing CUE file: $cue_file\e[0m"
      chdman createcd -i "$cue_file" -o "$chd_file"
    fi
  done
}

# Function to process ISO files
process_iso_files() {
  for iso_file in "$1"/**/*.iso; do
    if [ -e "$iso_file" ]; then
      base_name=$(basename "$iso_file" .iso)
      chd_file="$OUTPUT_DIR/$base_name.chd"
      echo -e "\e[32mProcessing ISO file: $iso_file\e[0m"
      chdman createcd -i "$iso_file" -o "$chd_file"
    fi
  done
}

# Function to process GDI files
process_gdi_files() {
  for gdi_file in "$1"/**/*.gdi; do
    if [ -e "$gdi_file" ]; then
      base_name=$(basename "$gdi_file" .gdi)
      data_files=("$1/${base_name}"*.bin "$1/${base_name}"*.raw)
      chd_file="$OUTPUT_DIR/$base_name.chd"
      echo -e "\e[32mProcessing GDI file: $gdi_file\e[0m"
      chdman createcd -i "$gdi_file" -o "$chd_file"
    fi
  done
}

# Process unzipped files in the INPUT_DIR and its subdirectories
process_cue_files "$INPUT_DIR"
process_iso_files "$INPUT_DIR"
process_gdi_files "$INPUT_DIR"

# Process ZIP archives
for zip_file in "$INPUT_DIR"/**/*.zip; do
  if [ -e "$zip_file" ]; then
    temp_dir="$OUTPUT_DIR/$(basename "$zip_file" .zip)"
    mkdir -p "$temp_dir"
    echo -e "\e[32mExtracting: $zip_file\e[0m"
    unzip -q "$zip_file" -d "$temp_dir"

    # Process extracted files
    process_cue_files "$temp_dir"
    process_iso_files "$temp_dir"
    process_gdi_files "$temp_dir"

    rm -rf "$temp_dir"
    echo -e "\e[32mTemporary folder $temp_dir successfully deleted.\e[0m"
  fi
done

# Check if no files were processed and print a message
if [ ! "$(find "$INPUT_DIR" -type f \( -name '*.cue' -o -name '*.iso' -o -name '*.gdi' -o -name '*.zip' \) -print -quit)" ]; then
  echo -e "\e[33mNo CUE, ISO, GDI, or ZIP files found in $INPUT_DIR or its subdirectories\e[0m"
fi
EOT

chmod +x "rom scripts/chdcreatecd.sh"

echo -e "\e[32mCreating chdcreatedvd.sh script...\e[0m"
cat << 'EOT' > "rom scripts/chdcreatedvd.sh"
#!/bin/bash

# Directory containing input files for createdvd (ISO and BIN/CUE)
INPUT_DIR="/storage/emulated/0/Download/Roms/DVD Input"
# Output directory for CHD files
OUTPUT_DIR="/storage/emulated/0/Download/Roms/DVD Output"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Enable nullglob and globstar to handle cases with no files found and to support recursive globbing
shopt -s nullglob globstar

# Function to process CUE files
process_cue_files() {
  for cue_file in "$1"/**/*.cue; do
    if [ -e "$cue_file" ]; then
      base_name=$(basename "$cue_file" .cue)
      chd_file="$OUTPUT_DIR/$base_name.chd"
      echo -e "\e[32mProcessing CUE file: $cue_file\e[0m"
      chdman createdvd -i "$cue_file" -o "$chd_file"
    fi
  done
}

# Function to process ISO files
process_iso_files() {
  for iso_file in "$1"/**/*.iso; do
    if [ -e "$iso_file" ]; then
      base_name=$(basename "$iso_file" .iso)
      chd_file="$OUTPUT_DIR/$base_name.chd"
      echo -e "\e[32mProcessing ISO file: $iso_file\e[0m"
      chdman createdvd -hs 2048 -i "$iso_file" -o "$chd_file"
    fi
  done
}

# Process unzipped files in the INPUT_DIR and its subdirectories
process_cue_files "$INPUT_DIR"
process_iso_files "$INPUT_DIR"

# Process ZIP archives
for zip_file in "$INPUT_DIR"/**/*.zip; do
  if [ -e "$zip_file" ]; then
    temp_dir="$OUTPUT_DIR/$(basename "$zip_file" .zip)"
    mkdir -p "$temp_dir"
    echo -e "\e[32mExtracting: $zip_file\e[0m"
    unzip -q "$zip_file" -d "$temp_dir"

    # Process extracted files
    process_cue_files "$temp_dir"
    process_iso_files "$temp_dir"

    rm -rf "$temp_dir"
    echo -e "\e[32mTemporary folder $temp_dir successfully deleted.\e[0m"
  fi
done

# Check if no files were processed and print a message
if [ ! "$(find "$INPUT_DIR" -type f \( -name '*.cue' -o -name '*.iso' -o -name '*.zip' \) -print -quit)" ]; then
  echo -e "\e[33mNo CUE, ISO, or ZIP files found in $INPUT_DIR or its subdirectories\e[0m"
fi
EOT

chmod +x "rom scripts/chdcreatedvd.sh"

EOF

echo -e "\e[32mCreating convert.sh script...\e[0m"
cat << 'EOT' > convert.sh

#!/data/data/com.termux/files/usr/bin/bash

# Function to run a script in the Ubuntu environment
run_script_in_ubuntu() {
  case $1 in
    1)
      proot-distro login ubuntu -- bash -c "cd ~/\"rom scripts\" && ./chdcreatecd.sh"
      ;;
    2)
      proot-distro login ubuntu -- bash -c "cd ~/\"rom scripts\" && ./chdcreatedvd.sh"
      ;;
    3)
      proot-distro login ubuntu -- bash -c "cd ~/\"rom scripts\" && ./iso2xex.sh"
      ;;
    4)
      proot-distro login ubuntu -- bash -c "cd ~/\"rom scripts\" && ./xex2zar.sh"
      ;;
    5)
      proot-distro login ubuntu -- bash -c "cd ~/\"rom scripts\" && ./iso2zar.sh"
      ;;
    6)
      proot-distro login ubuntu -- bash -c "cd ~/\"rom scripts\" && ./iso2god.sh"
      ;;
    *)
      echo -e "\e[31mInvalid choice. Please select a number between 1 and 6.\e[0m"
      ;;
  esac
}

# Display menu and prompt for user input
echo -e "\e[36m1) chdcreatecd.sh\e[0m"
echo -e "\e[33m2) chdcreatedvd.sh\e[0m"
echo -e "\e[36m3) iso2xex.sh\e[0m"
echo -e "\e[33m4) xex2zar.sh\e[0m"
echo -e "\e[36m5) iso2zar.sh\e[0m"
echo -e "\e[33m6) iso2god.sh\e[0m"

read -p "Enter your choice (1-6): " choice

# Run the script in the Ubuntu environment
run_script_in_ubuntu $choice

# Exit the script
exit 0
EOT

chmod +x convert.sh


echo -e "\e[35mSetup complete\e[0m"
echo -e "\e[32mTo use the conversion scripts, open Termux and type:\e[0m"
echo -e "\e[34m./convert.sh\e[0m"
echo -e "\e[32mThen choose the desired script:\e[0m"
echo -e "\e[34m./chdcreatecd.sh\e[0m" 
echo -e "\e[34m./chdcreatedvd.sh\e[0m"
echo -e "\e[34m./iso2xex.sh\e[0m"
echo -e "\e[34m./xex2zar.sh\e[0m"
echo -e "\e[34m./iso2zar.sh\e[0m"
echo -e "\e[34m./iso2god.sh\e[0m"
