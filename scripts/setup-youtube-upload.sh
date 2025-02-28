#!/bin/bash

# Setup script for YouTube upload functionality
# This script helps set up the youtube-upload tool and credentials

set -e

echo "Setting up YouTube upload capability..."

# Check if pip is installed
if ! command -v pip &>/dev/null; then
    echo "Error: pip not found. Please install Python and pip first."
    exit 1
fi

# Install youtube-upload if not already installed
if ! command -v youtube-upload &>/dev/null; then
    echo "Installing youtube-upload..."
    pip install youtube-upload
fi

# Check if credentials file exists
CREDENTIALS_FILE="$HOME/.youtube-upload-credentials.json"
if [ ! -f "$CREDENTIALS_FILE" ]; then
    echo "YouTube API credentials not found."
    echo ""
    echo "To create credentials:"
    echo "1. Go to Google Developers Console: https://console.developers.google.com/"
    echo "2. Create a new project"
    echo "3. Enable the YouTube Data API v3"
    echo "4. Create OAuth 2.0 credentials (Other UI/Desktop application)"
    echo "5. Download the client secrets JSON file"
    echo "6. Save it as $CREDENTIALS_FILE"
    echo ""
    read -p "Press Enter when you've completed these steps..."

    if [ ! -f "$CREDENTIALS_FILE" ]; then
        echo "Error: Credentials file still not found at $CREDENTIALS_FILE"
        exit 1
    fi
fi

echo "Setup complete! You can now use the upload_yt function in backtrack.sh"
echo "The first time you upload, you'll be prompted to authorize in a browser"
