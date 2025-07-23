FROM docker.io/nginx:alpine

# Install envsubst from gettext for template substitution
RUN apk add --no-cache gettext

# Copy the fixed config files 
COPY proxy/*.conf /etc/nginx/conf.d

WORKDIR /etc/nginx/app-config

# Copy scripts and template into image
COPY proxy/*.sh proxy/*.template .

# Make scripts executable
RUN chmod +x ./create_config.sh ./entrypoint.sh

# Set entrypoint script to run on container start
ENTRYPOINT ["./entrypoint.sh"]
