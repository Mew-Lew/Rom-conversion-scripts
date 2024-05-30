Before running the script, make sure to adjust the input and output paths located at the top of the script.

This script requires 2 output paths one for xex and one for zar.

This script serves to convert Xbox 360 iso files to zar format while preserving the original iso file.

It supports files in both .iso and .zip formats. If a zip file is provided, the script will automatically extract the iso file to a temporary folder within the output path, convert it to xex format, and then delete the extracted iso file. Once converted to zar the xex will also be deleted. The original zip file will remain intact.

Please be aware that I've only tested this script with zip files containing a single .iso file.

Additionally, if your iso file is within a zip, ensure you have at least 3.5 times the size of the zip file available in storage space. This accounts for the original zip file, the extracted xex, and the final zar file. If you're running low on storage space, it's advisable to convert only one iso file at a time.
