#!/bin/sh

# Usage: ./hostnames.sh [-c|--clean] [-d|--dry-run] [-y|--yes] [-h|--help] hostnames.conf

CLEAN_MODE=false
DRY_RUN=false
ASSUME_YES=false

# Function to show help
show_help() {
    cat << EOF
Usage: $0 [OPTIONS] hostnames.conf

Options:
  -c, --clean     Remove old dev-proxy entries that are no longer in hostnames.conf
  -d, --dry-run   Show what would be changed without actually modifying /etc/hosts
  -y, --yes       Automatically answer 'yes' to confirmation prompts
  -h, --help      Show this help message

Examples:
  $0 hostnames.conf                    # Add new hostnames only
  $0 -c hostnames.conf                # Clean old entries and add new ones
  $0 -d hostnames.conf                # Show what would change (dry run)
  $0 -y hostnames.conf                # Add new hostnames without confirmation
  $0 -c -y hostnames.conf             # Clean and add without confirmation

⚠️  WARNING: The -y/--yes option will automatically apply changes without
   asking for confirmation. Use with caution, especially with -c/--clean!

EOF
}

# Parse command line arguments
while [ $# -gt 0 ]; do
    case "$1" in
        -c|--clean)
            CLEAN_MODE=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -y|--yes)
            ASSUME_YES=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information."
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

if [ $# -ne 1 ]; then
    echo "Usage: $0 [OPTIONS] hostnames.conf"
    echo "Use -h or --help for usage information."
    exit 1
fi

NAMESFILE="$1"
if [ ! -f "$NAMESFILE" ]; then
    echo "File '$NAMESFILE' not found!"
    exit 2
fi

# Parse YAML and extract hostnames
# Look for lines that end with ':' (YAML keys) and extract the hostname part
HOSTNAMES=""
while IFS= read -r line; do
    # Skip empty lines and lines starting with #
    case "$line" in
        ""|\#*) continue ;;
    esac
    
    # Check if line ends with ':' (YAML key) with optional trailing whitespace
    if echo "$line" | grep -q ":[[:space:]]*$"; then
        # Extract hostname by removing trailing ':' and trimming whitespace
        hostname=$(echo "$line" | sed 's/:[[:space:]]*$//' | sed 's/^[[:space:]]*//')
        
        # Skip if hostname is empty
        if [ -n "$hostname" ]; then
            HOSTNAMES="$HOSTNAMES $hostname"
        fi
    fi
done < "$NAMESFILE"

# Check if we found any hostnames
if [ -z "$HOSTNAMES" ]; then
    echo "No valid hostnames found in '$NAMESFILE'."
    exit 3
fi

# Create a temporary file for the new /etc/hosts
TEMP_HOSTS=$(mktemp)

if [ "$CLEAN_MODE" = true ]; then
    echo "=== Clean mode: Processing existing dev-proxy entries ==="
    
    # Copy all lines except dev-proxy entries that are not in current config
    while IFS= read -r hosts_line; do
        # Check if this line is a dev-proxy entry
        if echo "$hosts_line" | grep -q "# dev-proxy"; then
            # Extract the hostname from the line
            old_hostname=$(echo "$hosts_line" | awk '{print $2}')
            
            # Check if this hostname is still in our current config
            keep_line=false
            for hostname in $HOSTNAMES; do
                if [ "$old_hostname" = "$hostname" ]; then
                    keep_line=true
                    break
                fi
            done
            
            # Only keep the line if hostname is still in current config
            if [ "$keep_line" = true ]; then
                echo "$hosts_line" >> "$TEMP_HOSTS"
                echo "Keeping existing entry: $old_hostname"
            else
                echo "Removing old entry: $old_hostname"
            fi
        else
            # Keep all non-dev-proxy lines
            echo "$hosts_line" >> "$TEMP_HOSTS"
        fi
    done < /etc/hosts
else
    # Copy existing /etc/hosts content
    cp /etc/hosts "$TEMP_HOSTS"
fi

echo "=== Adding new hostnames ==="
# Add new hostnames that don't already exist
for hostname in $HOSTNAMES; do
    # Check if the name already exists in our temp file
    if grep -qw "$hostname" "$TEMP_HOSTS"; then
        echo "$hostname already exists, skipping."
        continue
    fi

    # Add the entry with comment 'dev-proxy'
    echo "127.0.0.1  $hostname	# dev-proxy" >> "$TEMP_HOSTS"
    echo "Adding new entry: $hostname"
done

# Show the user what will be written to /etc/hosts
echo ""
echo "=== New /etc/hosts content ==="
cat "$TEMP_HOSTS"
echo "=== End of new content ==="
echo ""

# If there are no changes, do not ask for confirmation
if cmp -s "$TEMP_HOSTS" /etc/hosts; then
    echo "No changes. /etc/hosts is already up to date."
    rm "$TEMP_HOSTS"
    exit 0
fi

# Handle dry-run mode
if [ "$DRY_RUN" = true ]; then
    echo "DRY RUN MODE: No changes were made to /etc/hosts"
    echo "Use without -d/--dry-run to apply these changes"
    rm "$TEMP_HOSTS"
    exit 0
fi

# Ask for user confirmation only when changes exist and not in assume-yes mode
if [ "$ASSUME_YES" = false ]; then
    echo "Do you want to apply these changes to /etc/hosts? (y/N)"
    read -r response
else
    response="y"
fi

if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
    if sudo cp "$TEMP_HOSTS" /etc/hosts; then
        echo "✅ Changes applied successfully!"
    else
        echo "❌ Failed to apply changes to /etc/hosts." >&2
        rm "$TEMP_HOSTS"
        exit 4
    fi
else
    echo "Operation cancelled. No changes made to /etc/hosts."
fi

# Clean up temp file
rm "$TEMP_HOSTS"
