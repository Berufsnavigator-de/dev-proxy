#!/bin/sh

# Usage: ./certificates.sh [-l|--list] hostnames.conf

LIST_MODE=false

# Parse command line arguments
while [ $# -gt 0 ]; do
    case "$1" in
        -l|--list)
            LIST_MODE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS] [hostnames.conf]"
            echo ""
            echo "Options:"
            echo "  -l, --list     List current certificate information"
            echo "  -h, --help     Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 hostnames.conf                   # Create new certificates"
            echo "  $0 -l                               # List current certificates"
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

if [ "$LIST_MODE" = true ]; then
    # In list mode, hostnames file is optional
    if [ $# -eq 1 ]; then
        HOSTFILE="$1"
    fi
else
    # In normal mode, hostnames file is required
    if [ $# -ne 1 ]; then
        echo "Usage: $0 [-l|--list] <file_with_hostnames>"
        exit 1
    fi
    HOSTFILE="$1"
fi

# Check if required tools are available
if ! command -v mkcert >/dev/null 2>&1; then
    echo "Error: mkcert is not installed or not in PATH" >&2
    echo "Please install mkcert first:" >&2
    echo "  Arch: sudo pacman -S mkcert" >&2
    echo "  Ubuntu/Debian: sudo apt install mkcert" >&2
    echo "  macOS: brew install mkcert" >&2
    exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
    echo "Error: openssl is not installed or not in PATH" >&2
    echo "Please install openssl first:" >&2
    echo "  Arch: sudo pacman -S openssl" >&2
    echo "  Ubuntu/Debian: sudo apt install openssl" >&2
    echo "  macOS: brew install openssl" >&2
    exit 1
fi

CERTDIR="./certs"
PEM_FILE=$CERTDIR/cert.pem
KEY_FILE=$CERTDIR/cert.key
FULLCHAIN_FILE=$CERTDIR/fullchain.pem

if [ "$LIST_MODE" = true ]; then
    if [ -f "$PEM_FILE" ]; then
        echo "=== Certificate Information ==="
        echo "File: $PEM_FILE"
        echo ""
        
        # Check validity
        if openssl x509 -checkend 0 -noout -in "$PEM_FILE" 2>/dev/null; then
            echo "Status: ✅ Valid"
        else
            echo "Status: ❌ Invalid/Expired"
        fi
        
        echo ""
        echo "Validity:"
        echo "  Not Before: $(openssl x509 -in "$PEM_FILE" -noout -startdate | cut -d= -f2)"
        echo "  Not After:  $(openssl x509 -in "$PEM_FILE" -noout -enddate | cut -d= -f2)"
        
        echo ""
        echo "Alternative Names:"
        # Use -ext to directly query the Subject Alternative Name extension
        openssl x509 -in "$PEM_FILE" -noout -ext subjectAltName 2>/dev/null | grep -o 'DNS:[^,]*' | sed 's/DNS://' | while read -r dns; do
            [ -n "$dns" ] && echo "  $dns"
        done
    else
        echo "No certificate found at $PEM_FILE"
    fi
    exit 0
fi

# Only create certificates if not in list mode
if [ "$LIST_MODE" = false ]; then
    if [ ! -f "$HOSTFILE" ]; then
        echo "File '$HOSTFILE' not found!"
        exit 2
    fi

    # Create certs directory if it doesn't exist
    if [ ! -d "$CERTDIR" ]; then
        mkdir "$CERTDIR" || exit 3
    fi

    # Read hostnames (YAML): top-level keys like "hostname:" become SANs
    HOSTNAMES=""
    while IFS= read -r line; do
        case "$line" in
            ""|\#*) continue ;;
        esac
        if echo "$line" | grep -q '^[^[:space:]#][^:]*:[[:space:]]*$'; then
            name=$(echo "$line" | sed 's/:[[:space:]]*$//' | sed 's/[[:space:]]*$//')
            [ -n "$name" ] && HOSTNAMES="$HOSTNAMES $name"
        fi
    done < "$HOSTFILE"

    if [ -z "$HOSTNAMES" ]; then
        echo "No valid hostnames found in '$HOSTFILE'."
        exit 4
    fi

    mkcert -install
    mkcert -cert-file "$PEM_FILE" -key-file "$KEY_FILE" $HOSTNAMES
    cat $PEM_FILE "$(mkcert -CAROOT)/rootCA.pem" > "$FULLCHAIN_FILE"
fi

# podman doesn't work, because it would need the host's rootCA
# I could probably inject the correct file into the container,
# but to get the correct filename, I need mkcert -CAROOT,
# and then I can create the certificates directly on the host
# Alternative idea: Could I get the rootCA from the container?
# Run mkcert in a Podman container, mounting the certs directory
# podman run \
#     --rm -v "$(pwd)/$CERTDIR":/certs -w /certs \
#     docker.io/brunopadz/mkcert-docker \
#     mkcert -cert-file cert.pem -key-file cert.key $HOSTNAMES

# this gives an error 403
# podman run \
#     --log-level=debug \
#     --rm -v "$(pwd)/$CERTDIR":/certs -w /certs \
#     ghcr.io/filosottile/mkcert \
#     mkcert -cert-file cert.pem -key-file cert.key $HOSTNAMES

# The generated cert.pem and cert.key will be in the certs directory

