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

# URL validation: warn if it contains whitespace, but do not abort
check_url() {
    url="$1"
    if printf '%s\n' "$url" | grep -q '[[:space:]]'; then
        echo "Invalid URL (contains spaces). Encode spaces as %20: $url" >&2
    fi
}

# Parse YAML: lines with no indentation and ending with ':' start a new host
# Indented lines "  key: value" are locations for the current host
CURRENT_HOST=""
LOCATION_BLOCKS=""

flush_host() {
    # Render config for CURRENT_HOST using LOCATION_BLOCKS
    [ -z "$CURRENT_HOST" ] && return 0
    export HOSTNAME="$CURRENT_HOST"
    export LOCATION_BLOCKS="$LOCATION_BLOCKS"
    local config_file="${OUTPUT_DIR}/${CURRENT_HOST}.conf"
    envsubst < "$TEMPLATE" > "$config_file"
    echo "Wrote config: $config_file"
}

# Read YAML file
while IFS= read -r line || [ -n "$line" ]; do
    # Skip empty lines and full-line comments
    case "$line" in
        ""|\#*) continue ;;
    esac

    # Root-level hostname line: <name>:
    if echo "$line" | grep -q '^[^[:space:]#][^:]*:[[:space:]]*$'; then
        # Flush previous host before starting a new one
        flush_host
        CURRENT_HOST=$(echo "$line" | sed 's/:[[:space:]]*$//' | sed 's/[[:space:]]*$//')
        LOCATION_BLOCKS=""
        continue
    fi

    # Indented location line: <spaces><location>: <url>
    if echo "$line" | grep -q '^[[:space:]]\+[^:#][^:]*:[[:space:]]*[^[:space:]]'; then
        # POSIX-compliant extraction using printf + cut + sed
        location_key=$(printf '%s\n' "$line" | cut -d: -f1 | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        url_value=$(printf '%s\n' "$line" | cut -d: -f2- | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

        # Validate both values (warn only)
        check_url "$location_key"
        check_url "$url_value"
        
        # Append a location block
        LOCATION_BLOCKS="${LOCATION_BLOCKS}
    location ${location_key} {
        proxy_pass \"${url_value}\";
    }
"
        continue
    fi

    # Otherwise ignore line (allows comments after values or unknown lines)
done < "$NAMESFILE"

# Flush the last host
flush_host
