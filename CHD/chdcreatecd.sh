#!/bin/bash

# Directory containing input files for createcd (BIN/CUE, ISO, and GDI)
INPUT_DIR="CHANGE/INPUT/PATH"
# Output directory for CHD files
OUTPUT_DIR="CHANGE/OUTPUT/PATH"

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
      echo "Processing CUE file: $cue_file"
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
      echo "Processing ISO file: $iso_file"
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
      echo "Processing GDI file: $gdi_file"
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
    echo "Extracting: $zip_file"
    unzip -q "$zip_file" -d "$temp_dir"

    # Process extracted files
    process_cue_files "$temp_dir"
    process_iso_files "$temp_dir"
    process_gdi_files "$temp_dir"

    rm -rf "$temp_dir"
    echo "Temporary folder $temp_dir successfully deleted."
  fi
done

# Check if no files were processed and print a message
if [ ! "$(find "$INPUT_DIR" -type f \( -name '*.cue' -o -name '*.iso' -o -name '*.gdi' -o -name '*.zip' \) -print -quit)" ]; then
  echo "No CUE, ISO, GDI, or ZIP files found in $INPUT_DIR or its subdirectories"
fi
