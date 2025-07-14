#!/bin/sh

# Usage: ./hostnames.sh hostnames.conf

if [ $# -ne 1 ]; then
    echo "Usage: $0 <file_with_hostnames>"
    exit 1
fi

NAMESFILE="$1"
if [ ! -f "$NAMESFILE" ]; then
    echo "File '$NAMESFILE' not found!"
    exit 2
fi

while IFS= read -r name; do
    # Skip empty lines and lines starting with #
    case "$name" in
        ""|\#*) continue ;;
    esac

    # Check if the name already exists in /etc/hosts
    if grep -qw "$name" /etc/hosts; then
        echo "$name already exists in /etc/hosts, skipping."
        continue
    fi

    # Add the entry with comment 'dev-proxy'
    echo "127.0.0.1  $name	# dev-proxy" | sudo tee -a /etc/hosts > /dev/null
done < "$NAMESFILE"
