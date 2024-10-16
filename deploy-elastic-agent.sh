#!/bin/bash

set -e
set -u

log_file="/tmp/elastic-agent-install.log"

function log {
    local message="$1"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $message" >>"$log_file"
}

function cleanup {
    log "Cleaning up..."
    filename="elastic-agent-$version-$os_name-$architecture"
    if [ -d "/tmp/$filename" ]; then
        rm -rf "/tmp/$filename"
    fi
    if [ -f "/tmp/$filename.tar.gz" ]; then
        rm -f "/tmp/$filename.tar.gz"
    fi
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log "This script must be run as root"
    exit 1
fi

# Check if Elastic Agent is running
if pgrep "elastic-agent" >/dev/null; then
    log "Elastic Agent is currently running. Please uninstall it before running this script."
    exit -1
fi

# Suppress progress messages globally
export CURL_PROGRESS="--silent"

# Get the version number from the text file
function get_version_number {
    log "Fetching version number from https://repo.cyber.tamus.edu/elastic_agent_version.txt"
    version=$(curl $CURL_PROGRESS -fsSL -L --retry 3 "https://repo.cyber.tamus.edu/elastic_agent_version.txt")
    log "Fetched version number: $version"
    echo $version
}

# Determine the system architecture
function get_architecture {
    arch=$(uname -m)
    case $arch in
    x86_64)
        echo "x86_64"
        ;;
    arm64 | aarch64)
        echo "aarch64"
        ;;
    *)
        log "Unsupported architecture: $arch"
        exit 1
        ;;
    esac
}

# Download and install Elastic Agent
function install_elastic_agent {
    version=$1
    enrollment_token=$2
    architecture=$3
    os_name=$4

    # Set Linux architecture to arm64 if aarch64
    if [[ "$os_name" == "linux" && "$architecture" == "aarch64" ]]; then
        architecture="arm64"
    fi

    # Set the filename without the extension for use everywhere
    filename="elastic-agent-$version-$os_name-$architecture"

    # Determine the appropriate package URL based on the architecture and OS
    package_url="https://artifacts.elastic.co/downloads/beats/elastic-agent/$filename.tar.gz"

    # Move to the temporary directory
    cd /tmp || {
        log "Error: Unable to change directory"
        exit 1
    }

    log "Downloading Elastic Agent from $package_url"
    curl $CURL_PROGRESS -fsSL -OJ -L --retry 3 $package_url || {
        log "Error: Failed to download Elastic Agent"
        exit 1
    }

    # Delete the directory if it exists
    if [ -d "$filename" ]; then
        rm -rf "$filename"
    fi

    # Extract the tarball
    log "Extracting Elastic Agent to /tmp/$filename"
    tar -xzf "$filename.tar.gz" >/dev/null 2>&1 || {
        log "Error: Failed to extract Elastic Agent"
        exit 1
    }

    cd "$filename" || {
        log "Error: Unable to change directory"
        exit 1
    }

    log "Adding Execute permissions to Elastic Agent"
    chmod +x elastic-agent || {
        log "Error: Failed to add execute permissions to Elastic Agent"
        exit 1
    }
    
    log "Installing Elastic Agent"
    ./elastic-agent install --url=https://5ac984baeeff4bd89c566035d280569f.fleet.us-east-1.aws.found.io:443 --force --non-interactive --enrollment-token=$enrollment_token || {
        log "Error: Failed to install Elastic Agent"
        exit 1
    }
    log "Elastic Agent installation succeeded"
}

# Placeholder for the enrollment token
enrollment_token="R1g0MFVaRUJRandtUm1kVG54M3k6d3RMSm41Y0lRTWE1MFpPMl9BUW1lQQ=="

# Check if enrollment token is provided
if [[ -z "$enrollment_token" || "$enrollment_token" == "ENROLLMENT_TOKEN" ]]; then
    log "Error: No enrollment token provided"
    exit 1
fi

version=$(get_version_number)
architecture=$(get_architecture)
os_name=$(uname -s | tr '[:upper:]' '[:lower:]')

trap cleanup EXIT

install_elastic_agent $version $enrollment_token $architecture $os_name
