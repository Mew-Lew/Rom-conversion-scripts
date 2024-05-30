## Xbox 360 ISO to ZAR Converter

Before running the script, ensure to modify the input and output paths located at the top of the script.

### Prerequisites
- This script requires two output paths: one for XEX and one for ZAR.

### Overview
This script converts Xbox 360 ISO files to ZAR format while preserving the original ISO file.

- Supports files in both .iso and .zip formats.
- If a zip file is provided, the script will automatically extract the ISO file to a temporary folder within the output path, convert it to XEX format, and then delete the extracted ISO file.
- Once converted to ZAR, the XEX will also be deleted. The original zip file will remain intact.

### Notes
- The script has been tested with zip files containing a single .iso file.
- If your ISO file is within a zip, ensure you have at least 3.5 times the size of the zip file available in storage space. This accounts for the original zip file, the extracted XEX, and the final ZAR file.
- If storage space is low, it's advisable to convert only one ISO file at a time.
