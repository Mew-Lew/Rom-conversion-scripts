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

echo -e "\e[32mInstalling necessary tools in Ubuntu (wget, unzip, cmake, build-essential, zarchive-tools)...\e[0m"
apt install wget unzip cmake build-essential zarchive-tools -y

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

echo -e "\e[32mCreating iso2xex.sh script...\e[0m"
cat << 'EOT' > iso2xex.sh
#!/bin/bash

input_path="/storage/emulated/0/Download/ISO Input"
output_path="/storage/emulated/0/Download/XEX Output"

mkdir -p "$output_path"

files_processed=false

convert_iso_to_xex() {
    local iso_file="$1"
    local file_name=$(basename -- "$iso_file")
    local file_name_without_extension="${file_name%.*}"
    local iso_output_dir="$output_path/$file_name_without_extension"
    mkdir -p "$iso_output_dir"
    echo "Creating XEX file for $file_name..."
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
        echo "Extracting ZIP file $zip_file..."
        unzip -q "$zip_file" -d "$temp_dir"
        for iso_file in "$temp_dir"/*.iso; do
            if [ -f "$iso_file" ]; then
                convert_iso_to_xex "$iso_file"
                files_processed=true
            fi
        done
        rm -rf "$temp_dir"
        echo "Temporary folder for unzipped ISOs was deleted successfully."
    fi
done

if [ "$files_processed" = false ]; then
    echo "No ISO or ZIP files found to convert in the input directory."
else
    echo "All ISO files have been processed."
fi
EOT

chmod +x iso2xex.sh

echo -e "\e[32mCreating iso2zar.sh script...\e[0m"
cat << 'EOT' > iso2zar.sh
#!/bin/bash

input_path="/storage/emulated/0/Download/ISO Input"
xex_output_path="/storage/emulated/0/Download/XEX Output"
zar_output_path="/storage/emulated/0/Download/ZAR Output"

mkdir -p "$xex_output_path" "$zar_output_path"

convert_iso_to_xex() {
    local iso_file="$1"
    local temp_dir="$2"
    local file_name=$(basename -- "$iso_file")
    local file_name_without_extension="${file_name%.*}"
    local xex_output_dir="$xex_output_path/$file_name_without_extension"
    mkdir -p "$xex_output_dir"
    echo "Creating XEX file for $file_name..."
    if ! extract-xiso -x "$iso_file" -d "$xex_output_dir"; then
        echo "Failed to create XEX file for $file_name."
        return 1
    fi
    if [ -d "$temp_dir" ]; then
        rm -rf "$temp_dir"
        echo "Temporary ISO directory $temp_dir deleted after extracting XEX."
    fi
    convert_xex_to_zar "$xex_output_dir"
}

convert_xex_to_zar() {
    local xex_folder="$1"
    local folder_name=$(basename -- "$xex_folder")
    local zar_file="$zar_output_path/$folder_name.zar"
    if [ -f "$zar_file" ]; then
        echo "The output file $zar_file already exists. Removing it."
        rm -f "$zar_file"
    fi
    echo "Creating ZAR file for $folder_name..."
    if ! zarchive "$xex_folder" "$zar_file"; then
        echo "Failed to create ZAR file for $folder_name."
        return 1
    fi
    echo "ZAR file $zar_file created successfully."
    rm -rf "$xex_folder"
    echo "XEX folder $folder_name deleted after conversion to ZAR."
}

if [ ! -d "$input_path" ]; then
    echo "Input path $input_path does not exist."
    exit 1
elif [ -z "$(ls -A "$input_path")" ]; then
    echo "Input path $input_path is empty."
    exit 1
fi

iso_files_found=false
for iso_file in "$input_path"/*.iso; do
    if [ -f "$iso_file" ]; then
        iso_files_found=true
        echo "Processing ISO file: $iso_file"
        convert_iso_to_xex "$iso_file" ""
    fi
done

zip_files_found=false
for zip_file in "$input_path"/*.zip; do
    if [ -f "$zip_file" ]; then
        zip_files_found=true
        temp_dir="$xex_output_path/temporary_$(basename -- "$zip_file" .zip)"
        mkdir -p "$temp_dir"
        echo "Extracting ZIP file $zip_file..."
        if unzip -q "$zip_file" -d "$temp_dir"; then
            for iso_file in "$temp_dir"/*.iso; do
                if [ -f "$iso_file" ]; then
                    convert_iso_to_xex "$iso_file" "$temp_dir"
                fi
            done
        else
            echo "Failed to extract ZIP file $zip_file."
            rm -rf "$temp_dir"
            echo "Temporary directory $temp_dir deleted due to extraction failure."
        fi
    fi
done

if [ "$iso_files_found" = false ] && [ "$zip_files_found" = false ]; then
    echo "No ISO or ZIP files found in $input_path."
fi

echo "Processing completed."
EOT

chmod +x iso2zar.sh

echo -e "\e[32mCreating xex2zar.sh script...\e[0m"
cat << 'EOT' > xex2zar.sh
#!/bin/bash

input_path="/storage/emulated/0/Download/XEX Input"
output_path="/storage/emulated/0/Download/ZAR Output"

if [ ! -d "$input_path" ]; then
    echo "Error: Input path does not exist"
    exit 1
fi

if [ ! -d "$output_path" ]; then
    mkdir -p "$output_path"
fi

for folder in "$input_path"/*; do
    if [ -d "$folder" ]; then
        echo "Converting folder: $(basename "$folder")"
        zarchive "$folder" "$output_path/$(basename "$folder").zar"
        if [ $? -eq 0 ]; then
            echo "Successfully converted $(basename "$folder") to zar file"
        else
            echo "Error: Failed to convert $(basename "$folder")"
        fi
    fi
done

if [ -z "$(ls -A "$input_path")" ]; then
    echo "Nothing to convert in the input path"
fi
EOT

chmod +x xex2zar.sh

EOF

echo -e "\e[32mSetup complete. Scripts iso2xex.sh, iso2zar.sh, and xex2zar.sh have been created.\e[0m"
