# This script uses extract-xiso under the license provided in extract-xiso-license.txt


# This script requires wget unzip cmake zarchive-tools build-essential

#!/bin/bash

# Input and output paths
input_path="CHANGE/ME/INPUT/PATH"
output_path="CHANGE/ME/OUTPUT/PATH"

# Check if the output directory exists, if not, create it
mkdir -p "$output_path"

# Flag to track if any files were processed
files_processed=false

# Function to convert ISO to XEX
convert_iso_to_xex() {
    local iso_file="$1"
    local file_name=$(basename -- "$iso_file")
    local file_name_without_extension="${file_name%.*}"
    
    # Create directory for output files
    local iso_output_dir="$output_path/$file_name_without_extension"
    mkdir -p "$iso_output_dir"
    
    # Perform the conversion
    echo "Creating XEX file for $file_name..."
    extract-xiso -x "$iso_file" -d "$iso_output_dir"
}

# Loop through each ISO file in the input directory
for iso_file in "$input_path"/*.iso; do
    if [ -f "$iso_file" ]; then
        convert_iso_to_xex "$iso_file"
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

        # Find all ISO files in the unzipped content and convert them
        for iso_file in "$temp_dir"/*.iso; do
            if [ -f "$iso_file" ]; then
                convert_iso_to_xex "$iso_file"
                files_processed=true
            fi
        done

        # Clean up temporary directory
        rm -rf "$temp_dir"
        echo "Temporary folder for unzipped ISOs was deleted successfully."
    fi
done

# Check if any files were processed
if [ "$files_processed" = false ]; then
    echo "No ISO or ZIP files found to convert in the input directory."
else
    echo "All ISO files have been processed."
fi
