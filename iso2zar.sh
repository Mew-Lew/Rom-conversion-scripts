# This script requires wget unzip cmake zarchive-tools build-essential

#1 Download the extract-xiso source code from GitHub
# wget https://github.com/XboxDev/extract-xiso/archive/refs/heads/master.zip

#2 Unzip the downloaded file
# unzip master.zip

#3 Navigate to the source directory
# cd extract-xiso-master

#4 Create a build directory and navigate to the build directory
# mkdir build
# cd build

#5 Configure the project
# cmake ..

#6 Compile the project
# make

#7 Install the compiled project
# make install

#!/bin/bash

# Input and output paths
input_path="CHANGE/ME/INPUT/PATH"
xex_output_path="CHANGE/ME/OUTPUT/XEX"
zar_output_path="CHANGE/ME/OUTPUT/ZAR"

# Ensure output directories exist
mkdir -p "$xex_output_path" "$zar_output_path"

# Function to convert ISO to XEX
convert_iso_to_xex() {
    local iso_file="$1"
    local temp_dir="$2"
    local file_name=$(basename -- "$iso_file")
    local file_name_without_extension="${file_name%.*}"
    local xex_output_dir="$xex_output_path/$file_name_without_extension"

    # Create directory for output files
    mkdir -p "$xex_output_dir"

    # Perform the conversion
    echo "Creating XEX file for $file_name..."
    if ! extract-xiso -x "$iso_file" -d "$xex_output_dir"; then
        echo "Failed to create XEX file for $file_name."
        return 1
    fi

    # Delete temporary directory containing extracted ISO files
    if [ -d "$temp_dir" ]; then
        rm -rf "$temp_dir"
        echo "Temporary ISO directory $temp_dir deleted after extracting XEX."
    fi

    # Convert XEX to ZAR
    convert_xex_to_zar "$xex_output_dir"
}

# Function to convert XEX to ZAR
convert_xex_to_zar() {
    local xex_folder="$1"
    local folder_name=$(basename -- "$xex_folder")
    local zar_file="$zar_output_path/$folder_name.zar"

    # Check if the ZAR file already exists and remove it
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

# Check if the input path exists and is not empty
if [ ! -d "$input_path" ]; then
    echo "Input path $input_path does not exist."
    exit 1
elif [ -z "$(ls -A "$input_path")" ]; then
    echo "Input path $input_path is empty."
    exit 1
fi

# Process ISO files
iso_files_found=false
for iso_file in "$input_path"/*.iso; do
    if [ -f "$iso_file" ]; then
        iso_files_found=true
        echo "Processing ISO file: $iso_file"
        convert_iso_to_xex "$iso_file" ""
    fi
done

# Process ZIP files
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
