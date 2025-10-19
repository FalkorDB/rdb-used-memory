#!/bin/bash

log() {
    if [ "$DEBUG" == "1" ]; then
        echo "$1"
    fi
}

# Check for xxd
if ! command -v xxd &> /dev/null; then
    echo "Error: 'xxd' not found."
    exit 1
fi

# Check for bc
if ! command -v bc &> /dev/null; then
    echo "Error: 'bc' not found."
    exit 1
fi

if [ -z "$1" ]; then
    echo "Usage: $0 <rdb_file>"
    exit 1
fi

RDB_FILE="$1"
if [ ! -f "$RDB_FILE" ]; then
    echo "RDB file not found"
    exit 1
fi

prefix="fa08757365642d6d656d"

# Dump first 500 bytes
hex=$(xxd -p -l 500 "$RDB_FILE" | tr -d '\n')
after_prefix=${hex#*$prefix}

if [ "$after_prefix" = "$hex" ]; then
    echo "used-mem aux field not found"
    exit 1
fi

# Read first byte to get encoding
length_byte_hex=${after_prefix:0:2}
length_byte=$((16#$length_byte_hex))

# Initialize used_mem_bytes
used_mem_bytes=0

# Handle RDB string/integer encodings for the value
enc_type=$(( (length_byte & 0xC0) >> 6 ))
lower6=$(( length_byte & 0x3F ))
log "Length byte: $length_byte_hex, enc_type: $enc_type, lower6: $lower6"

# Position in hex string (after prefix)
pos=2

if [ $enc_type -eq 0 ]; then
    # 6-bit length string (0-63 bytes)
    str_len=$lower6
    log "6-bit string length: $str_len"
elif [ $enc_type -eq 1 ]; then
    # 14-bit length string
    next_byte_hex=${after_prefix:$pos:2}
    next_byte=$((16#$next_byte_hex))
    str_len=$(( (lower6 << 8) | next_byte ))
    pos=$((pos + 2))
    log "14-bit string length: $str_len"
elif [ $length_byte -eq 128 ]; then
    # 32-bit length (0x80 = 128)
    str_len_hex=${after_prefix:$pos:8}
    str_len=$((16#$str_len_hex))
    pos=$((pos + 8))
    log "32-bit string length: $str_len"
elif [ $length_byte -eq 129 ]; then
    # 64-bit length (0x81 = 129)
    str_len_hex=${after_prefix:$pos:16}
    str_len=$((16#$str_len_hex))
    pos=$((pos + 16))
    log "64-bit string length: $str_len"
elif [ $enc_type -eq 3 ]; then
    # ENCVAL - Special encoded values
    sub_type=$lower6
    if [ $sub_type -eq 0 ]; then
        # int8
        val_hex=${after_prefix:$pos:2}
        val=$((16#$val_hex))
        used_mem_bytes=$val
        log "ENCVAL int8: $val"
    elif [ $sub_type -eq 1 ]; then
        # int16 (little-endian)
        val_hex=${after_prefix:$pos:4}
        byte1=${val_hex:0:2}
        byte2=${val_hex:2:2}
        # Reverse for little-endian
        reversed_hex="${byte2}${byte1}"
        val=$((16#$reversed_hex))
        used_mem_bytes=$val
        log "ENCVAL int16: $val"
    elif [ $sub_type -eq 2 ]; then
        # int32 (little-endian)
        val_hex=${after_prefix:$pos:8}
        byte1=${val_hex:0:2}
        byte2=${val_hex:2:2}
        byte3=${val_hex:4:2}
        byte4=${val_hex:6:2}
        # Reverse for little-endian
        reversed_hex="${byte4}${byte3}${byte2}${byte1}"
        val=$((16#$reversed_hex))
        used_mem_bytes=$val
        log "ENCVAL int32: $val"
    else
        echo "Unsupported ENCVAL type $sub_type"
        exit 1
    fi
else
    echo "Unknown encoding type: $enc_type"
    exit 1
fi

# If used_mem_bytes still zero, read ASCII string
if [ $used_mem_bytes -eq 0 ]; then
    str_hex=${after_prefix:$pos:$((str_len*2))}
    used_mem_ascii=$(echo "$str_hex" | xxd -r -p)
    # convert ASCII string to number
    used_mem_bytes=$((10#$used_mem_ascii))
    log "Used-mem ASCII string: $used_mem_ascii -> $used_mem_bytes bytes"
fi

used_mem_mb=$(echo "scale=2; $used_mem_bytes/1024/1024" | bc)
echo "$used_mem_mb"