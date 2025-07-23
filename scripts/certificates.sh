#!/bin/sh

# Usage: ./mkcert_podman.sh hostnames.txt

if [ $# -ne 1 ]; then
    echo "Usage: $0 <file_with_hostnames>"
    exit 1
fi

HOSTFILE="$1"
CERTDIR="./certs"
PEM_FILE=$CERTDIR/cert.pem
KEY_FILE=$CERTDIR/cert.key
FULLCHAIN_FILE=$CERTDIR/fullchain.pem

if [ ! -f "$HOSTFILE" ]; then
    echo "File '$HOSTFILE' not found!"
    exit 2
fi

# Create certs directory if it doesn't exist
if [ ! -d "$CERTDIR" ]; then
    mkdir "$CERTDIR" || exit 3
fi

# Read hostnames into a single line
HOSTNAMES=""
while read -r name rest; do
    case "$name" in
        ""|\#*) continue ;;
    esac
    HOSTNAMES="$HOSTNAMES $name"
done < "$HOSTFILE"

if [ -z "$HOSTNAMES" ]; then
    echo "No valid hostnames found in '$HOSTFILE'."
    exit 4
fi

mkcert -install
mkcert -cert-file "$PEM_FILE" -key-file "$KEY_FILE" $HOSTNAMES
cat $PEM_FILE "$(mkcert -CAROOT)/rootCA.pem" > "$FULLCHAIN_FILE"

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

