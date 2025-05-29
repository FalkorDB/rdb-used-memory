#!/bin/bash

# Check if xxd is installed
if ! command -v xxd &> /dev/null
then
    echo "Error: 'xxd' command not found. Please install it (e.g., 'sudo apt-get install xxd' or 'sudo yum install vim-common')."
    exit 1
fi

# Check for RDB file argument
if [ -z "$1" ]; then
    echo "Usage: $0 <rdb_file>"
    echo "This script extracts the 'used-mem' auxiliary field from a Redis RDB file"
    echo "and outputs its value in bytes, based on a specific RDB format assumption."
    exit 1
fi

RDB_FILE="$1"

# Check if the RDB file exists
if [ ! -f "$RDB_FILE" ]; then
    echo "Error: RDB file '$RDB_FILE' not found."
    exit 1
fi

# Define the exact hexadecimal prefix for the "used-mem" auxiliary field:
# FA   : RDB_OPCODE_AUX (Auxiliary field indicator)
# 08   : Length of the key "used-mem" (8 bytes)
# 757365642D6D656D : "used-mem" in ASCII hex
# C2   : RDB_ENC_INT32 (indicates a 32-bit integer follows)
SEARCH_PREFIX="FA08757365642D6D656DC2"

# Get the full hexadecimal dump of the RDB file
# -p: plain hexdump (no offset, no ASCII)
# -c 256: output 256 bytes per line (reduces newlines)
# tr -d '\n': remove all newlines to create a single continuous hex string
HEX_DUMP=$(xxd -p -c 256 "$RDB_FILE" | tr -d '\n')

# Find the pattern and extract the 8 hex characters (4 bytes) immediately following it.
# \K discards the prefix, so only the captured bytes are printed.
# head -n 1: in case the pattern appears multiple times, take the first one.
FOUR_BYTES_HEX=$(echo "$HEX_DUMP" | grep -o -i -E "${SEARCH_PREFIX}.{8}" | head -n 1 | sed "s/^${SEARCH_PREFIX}//ig")

if [ -z "$FOUR_BYTES_HEX" ]; then
    echo "Error: 'used-mem' auxiliary field not found with the expected prefix in '$RDB_FILE'."
    echo "Expected prefix: $SEARCH_PREFIX followed by 4 bytes of data."
    exit 1
fi

# Extract byte pairs and reverse them for little-endian to big-endian conversion
# Example: If FOUR_BYTES_HEX is "E8891500" (little-endian bytes: 00 15 89 E8)
# We want to form "001589E8" for direct hex conversion.
BYTE1=${FOUR_BYTES_HEX:0:2} # E8
BYTE2=${FOUR_BYTES_HEX:2:2} # 89
BYTE3=${FOUR_BYTES_HEX:4:2} # 15
BYTE4=${FOUR_BYTES_HEX:6:2} # 00

REVERSED_HEX="${BYTE4}${BYTE3}${BYTE2}${BYTE1}" # 001589E8

# Convert the reversed hexadecimal string to a decimal integer
# Bash arithmetic expansion $((16#HEX_STRING)) handles base conversion
DEC_VALUE=$((16#$REVERSED_HEX))

echo "$DEC_VALUE"