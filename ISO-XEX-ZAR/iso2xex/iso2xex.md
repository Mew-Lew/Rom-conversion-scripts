## Xbox 360 ISO to XEX Converter

Before running the script, ensure to modify the input and output paths located at the top of the script.

### Prerequisites
- This script requires adjusting the input and output paths.
- It also requires at least 3.5 times the size of the input zip file available in storage space if the ISO file is within a zip.

### Overview
This script converts Xbox 360 ISO files to XEX format while preserving the original ISO file.

- Supports files in both .iso and .zip formats.
- If a zip file is provided, the script will automatically extract the ISO file to a temporary folder within the output path, convert it to XEX format, and then delete the extracted ISO file.
- The original iso or zip file will remain intact.

### Notes
- The script has been tested with zip files containing a single .iso file.
- Ensure sufficient storage space is available if the ISO file is within a zip.
- It's advisable to convert only one ISO file at a time if storage space is low.
