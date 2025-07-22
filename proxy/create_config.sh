#! /bin/sh 

# Usage: ./create_config.sh hostnames.conf <output_dir>

CONFIG_DIR=$(dirname "$0")
TEMPLATE="$CONFIG_DIR/hostname.conf.template"
OUTPUT_DIR_DEFAULT="/etc/nginx/conf.d"

if [ "$#" -ne 1 ] && [ "$#" -ne 2 ]; then
    echo "Usage: $0 <file_with_hostnames> [output_dir]"
    exit 1
fi

NAMESFILE="$1"
if [ ! -f "$NAMESFILE" ]; then
    echo "File '$NAMESFILE' not found!"
    exit 2
fi

if [ ! -f "$TEMPLATE" ]; then
    echo "Template file '$TEMPLATE' not found!"
    exit 3
fi

OUTPUT_DIR="${2:-$OUTPUT_DIR_DEFAULT}"
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Directory '$OUTPUT_DIR' not found! Will create it now"
    mkdir -p "$OUTPUT_DIR"
fi

while read -r HOSTNAME FRONTEND_PORT BACKEND_PORT BACKEND_URI; do
    # skip empty lines and comments
    [ -z "$HOSTNAME" ] && continue
    case "$HOSTNAME" in \#*) continue ;; esac

    export HOSTNAME FRONTEND_PORT BACKEND_PORT BACKEND_URI
    envsubst < "$TEMPLATE" > "$OUTPUT_DIR/${HOSTNAME}.conf"
done < "$NAMESFILE"

