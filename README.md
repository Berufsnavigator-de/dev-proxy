# Dev Proxy

A local HTTPS reverse proxy for development, built on Nginx and Podman. It terminates TLS with mkcert-generated certificates and forwards requests to services running on your host by hostname.

## Features

- 🔒 **HTTPS with local certificates** - Uses mkcert for trusted local development
- 🚀 **Simple YAML configuration** - Easy-to-read hostname and location mapping
- 🧹 **Automatic cleanup** - Remove old entries that are no longer in config
- 🔍 **Dry-run mode** - Preview changes before applying them
- 📋 **Certificate management** - Generate and inspect certificates easily
- 🐳 **Podman-based** - Consistent environment across different systems

## Prerequisites

- **Container runtime**: Either **Podman** (tested) or **Docker** (untested)
- **Compose tool**: **Podman Compose** or **Docker Compose**
- **mkcert** for local certificate generation
- **OpenSSL** for certificate inspection

## Quick Start

### 1. Clone and Setup

```bash
git clone Berufsnavigator-de/dev-proxy
cd dev-proxy
```

### 2. Initialize mkcert (Arch Linux)

```bash
./scripts/init-arch.sh
```

**For other systems:**
- **Ubuntu/Debian**: `sudo apt install mkcert && mkcert -install`
- **macOS**: `brew install mkcert && mkcert -install`
- **Fedora/RHEL**: `sudo dnf install mkcert && mkcert -install`

### 3. Create Configuration

Create `hostnames.conf` with your local hostnames and proxy mappings:

```yaml
app.local:
  /: http://host.containers.internal:3000
  /api: http://host.containers.internal:4000

admin.local:
  /: http://host.containers.internal:3100

api.local:
  /: http://host.containers.internal:8000
  /docs: http://host.containers.internal:8001
```

### 4. Generate Certificates

```bash
./scripts/certificates.sh hostnames.conf
```

### 5. Update Hosts File

```bash
./scripts/hostnames.sh hostnames.conf
```

### 6. Start the Proxy

```bash
podman compose up -d
```

Your services are now available at:
- `https://app.local:8443`
- `https://admin.local:8443`
- `https://api.local:8443`

## Configuration Format

The `hostnames.conf` file uses a simple YAML format:

```yaml
hostname.local:
  /: http://backend:port
  /api: http://api-backend:port
  /admin: http://admin-backend:port
```

- **Top-level keys** are the hostnames (e.g., `app.local`)
- **Indented entries** map URL paths to backend services
- **Backend URLs** should not contain spaces (use %20 encoding if needed)

## Scripts

### `scripts/hostnames.sh`

Manages `/etc/hosts` entries for your local hostnames.

```bash
# Add new hostnames
./scripts/hostnames.sh hostnames.conf

# Clean old entries and add new ones
./scripts/hostnames.sh -c hostnames.conf

# Preview changes without applying
./scripts/hostnames.sh -d hostnames.conf

# Apply changes without confirmation
./scripts/hostnames.sh -y hostnames.conf

# Show help
./scripts/hostnames.sh -h
```

**Options:**
- `-c, --clean` - Remove old dev-proxy entries not in current config
- `-d, --dry-run` - Show what would change without applying
- `-y, --yes` - Automatically answer "yes" to confirmations
- `-h, --help` - Show help information

### `scripts/certificates.sh`

Generates and manages SSL certificates for your hostnames.

```bash
# Generate new certificates
./scripts/certificates.sh hostnames.conf

# List current certificates
./scripts/certificates.sh -l

# Show help
./scripts/certificates.sh -h
```

**Options:**
- `-l, --list` - Display current certificate information
- `-h, --help` - Show help information

### `scripts/init-arch.sh`

Arch Linux-specific script to install and configure mkcert.

## Container Runtime

The proxy runs in a container with:

- **Port**: `8443` (HTTPS)
- **Certificates**: Mounted from `./certs/`
- **Configuration**: Generated from `hostnames.conf`

### Container Structure

- **Base**: `nginx:alpine`
- **Config generation**: Automatic on startup
- **Template processing**: Uses `envsubst` for dynamic configuration
- **Proxy headers**: Standard headers + WebSocket support

**Note**: This project is tested and optimized for Podman.

## Troubleshooting

### Certificate Issues

```bash
# Check certificate status
./scripts/certificates.sh -l

# Regenerate certificates
./scripts/certificates.sh hostnames.conf
```

### Hosts File Issues

```bash
# Check current entries
./scripts/hostnames.sh -d hostnames.conf

# Clean and reapply
./scripts/hostnames.sh -c hostnames.conf
```

### Nginx Configuration

```bash
# View generated configs
podman compose exec dev-proxy cat /etc/nginx/conf.d/app.local.conf
```

## Development

### Project Structure

```
dev-proxy/
├── certs/                    # SSL certificates
├── compose.yaml             # Docker Compose configuration
├── Dockerfile               # Nginx container definition
├── hostnames.conf           # Hostname configuration (create this)
├── proxy/                   # Nginx configuration files
│   ├── create_config.sh     # Config generator
│   ├── hostname.conf.template # Nginx server template
│   └── proxy_headers.conf   # Standard proxy headers
├── scripts/                 # Utility scripts
│   ├── certificates.sh      # Certificate management
│   ├── hostnames.sh         # Hosts file management
│   └── init-arch.sh         # Arch Linux setup
└── README.md                # This file
```

### Adding New Features

1. **Scripts**: Keep them POSIX-compliant for portability
2. **Configuration**: Use simple, readable formats (YAML)
3. **Error handling**: Provide clear error messages and help
4. **Documentation**: Update this README for any changes
