#!/bin/bash

# This script utilizes extract-xiso downloaded from [https://github.com/XboxDev/extract-xiso/tree/master].
# The license terms are detailed in the extract-xiso-license.txt file included in this repository.

# Input and output paths
input_path="CHANGE/INPUT/PATH"
output_path="CHANGE/OUTPUT/PATH"

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
    echo -e "\e[31mConversion cancelled by user.\e[0m"
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

# Function to convert rewritten ISO to GOD
convert_to_god() {
    local rewritten_iso="$1"
    local file_name=$(basename -- "$rewritten_iso")

    echo "Converting rewritten ISO file $file_name to GOD..."
    (cd && ./iso2god-rs/target/release/iso2god "$rewritten_iso" "$output_path")
    if [ $? -eq 0 ]; then
        echo -e "\e[32mGOD file for $file_name created successfully.\e[0m"
        # Delete rewritten ISO if the user chose not to keep it
        if [ "$choice" == "2" ]; then
            rm -f "$rewritten_iso"
            echo -e "\e[32mRewritten ISO file $file_name deleted.\e[0m"
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
    echo -e "\e[32mAll ISO files have been rewritten and converted to GOD.\e[0m"
fi
