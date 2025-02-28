#!/usr/bin/env python3

import os
import json
import sys
from pathlib import Path


def setup_youtube_credentials():
    """
    Guide the user through setting up YouTube API credentials
    """
    credentials_path = os.path.expanduser("~/.youtube-upload-credentials.json")

    print("\n=== YouTube API Credentials Setup ===\n")
    print(
        "This script will help you set up YouTube API credentials for uploading videos."
    )
    print("\nFollow these steps:")
    print("1. Go to https://console.cloud.google.com/")
    print("2. Create a new project or select an existing one")
    print("3. Enable the YouTube Data API v3")
    print("4. Create OAuth 2.0 credentials (OAuth client ID)")
    print("   - Application type: Desktop application")
    print("   - Name: YouTube Uploader")
    print("5. Download the credentials JSON file")

    input("\nPress Enter when you're ready to continue...")

    print(
        "\nNow, you need to provide the path to the downloaded credentials JSON file."
    )
    while True:
        downloaded_file = input("Enter the full path to the downloaded JSON file: ")
        downloaded_file = os.path.expanduser(downloaded_file)

        if not os.path.exists(downloaded_file):
            print(f"File not found: {downloaded_file}")
            continue

        try:
            with open(downloaded_file, "r") as f:
                credentials_data = json.load(f)

            # Ensure this is the right type of file
            if "installed" not in credentials_data:
                print(
                    "This doesn't appear to be a valid OAuth client credentials file."
                )
                continue

            # Save the credentials file
            with open(credentials_path, "w") as f:
                json.dump(credentials_data, f)

            print(f"\nCredentials successfully saved to {credentials_path}")
            print(
                "\nThe first time you upload a video, you'll need to authorize the application."
            )
            print(
                "A browser window will open for you to sign in to your YouTube account."
            )
            return True

        except Exception as e:
            print(f"Error processing credentials file: {e}")

    return False


if __name__ == "__main__":
    setup_youtube_credentials()
