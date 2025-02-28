#!/usr/bin/env python3

import os
import sys
import re
from youtube_upload.client import YoutubeUploader


def upload_video(video_file):
    """
    Upload a video to YouTube using the youtube_upload API
    """
    # Extract base filename for title
    filename = os.path.basename(video_file)
    # Remove .black.mp4 or similar extensions for cleaner title
    title = re.sub(r"\.black\.mp4$", "", filename)
    title = f"Backtrack {title}"

    # Default options
    options = {
        "title": title,
        "description": "Automatically uploaded backtrack video",
        "tags": ["backtrack", "audio"],
        "privacyStatus": "unlisted",  # Can be "private", "public", or "unlisted"
        "kids": False,
    }

    try:
        # Check if credentials file exists
        credentials_path = os.path.expanduser("~/.youtube-upload-credentials.json")
        if not os.path.exists(credentials_path):
            print(f"Error: YouTube credentials not found at {credentials_path}")
            print("Please set up YouTube API credentials first by running:")
            print("\n    python ~/dotfiles/scripts/setup_youtube_credentials.py\n")
            return 1

        # Initialize uploader with the credentials
        uploader = YoutubeUploader(secrets_file_path=credentials_path)

        # Authenticate
        print(f"Authenticating with YouTube...")
        oauth_path = os.path.expanduser("~/.youtube-upload-oauth.json")

        # Try to use existing oauth tokens if available
        if os.path.exists(oauth_path):
            # copy oauth_path to ./oauth.json:
            with open(oauth_path, "r") as f:
                with open("./oauth.json", "w") as f2:
                    f2.write(f.read())

            try:
                uploader.authenticate()
                print("Authentication successful using saved tokens")
            except Exception:
                print(
                    "Saved authentication expired. Opening browser for new authentication..."
                )
                uploader.authenticate()
                # Save oauth tokens for future use
                if hasattr(uploader, "oauth") and uploader.oauth:
                    with open(oauth_path, "w") as f:
                        f.write(uploader.oauth)
        else:
            print("First-time authentication. Opening browser for authorization...")
            uploader.authenticate()
            with open("./oauth.json", "r") as f:
                with open(oauth_path, "w") as f2:
                    f2.write(f.read())

        # Upload video
        print(f"Uploading {video_file} to YouTube with title: {title}")
        video_id = uploader.upload(video_file, options)

        print(f"Upload complete for {video_file}")
        print(f"Video ID: {video_id}")
        print(f"Video URL: https://youtu.be/{video_id}")
        return 0

    except Exception as e:
        print(f"Failed to upload {video_file}: {str(e)}")
        return 1


if __name__ == "__main__":
    video_file = os.environ.get("VIDEO_FILE")
    if not video_file:
        print("Error: VIDEO_FILE environment variable not set")
        sys.exit(1)

    if not os.path.exists(video_file):
        print(f"Error: Video file not found: {video_file}")
        sys.exit(1)

    sys.exit(upload_video(video_file))
