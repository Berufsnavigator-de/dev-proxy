#!/bin/sh

./create_config.sh ./hostnames.conf

exec nginx -g 'daemon off;'
