#!/bin/bash

input_path="CHANGE/ME/INPUT/PATH"
output_path="CHANGE/ME/OUTPUT/PATH"

# Check if input_path exists
if [ ! -d "$input_path" ]; then
    echo "Error: Input path does not exist"
    exit 1
fi

# Check if output_path exists, if not create it
if [ ! -d "$output_path" ]; then
    mkdir -p "$output_path"
fi

# Loop through each folder in input_path
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

# Check if there's nothing to convert
if [ -z "$(ls -A "$input_path")" ]; then
    echo "Nothing to convert in the input path"
fi
