#!/usr/bin/env python3

import os
import sys
import re
import datetime
from youtube_upload.client import YoutubeUploader


def upload_video(video_file):
    """
    Upload a video to YouTube using the youtube_upload API
    """
    # Extract base filename for title
    filename = os.path.basename(video_file)
    # Remove .black.mp4 or similar extensions for cleaner title
    title = re.sub(r"\.black\.mp4$", "", filename)
    title = re.sub(r"\..{3,4}$", "", title)

    # Get file creation date
    creation_time = os.path.getctime(video_file)
    creation_date = datetime.datetime.fromtimestamp(creation_time)
    date_str = creation_date.strftime("%Y-%m-%d")

    # Add date to the title
    title = f"{date_str}: {title}"

    # Default options
    options = {
        "title": title,
        "description": "Automatically uploaded meeting video",
        "tags": ["backtrack", "audio", "meeting"],
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

        # Function to handle authentication
        def authenticate_user():
            uploader.authenticate()
            # Save oauth tokens for future use
            if os.path.exists("./oauth.json"):
                with open("./oauth.json", "r") as f:
                    with open(oauth_path, "w") as f2:
                        f2.write(f.read())

        # Try to use existing oauth tokens if available
        if os.path.exists(oauth_path):
            # copy oauth_path to ./oauth.json:
            with open(oauth_path, "r") as f:
                with open("./oauth.json", "w") as f2:
                    f2.write(f.read())

            try:
                uploader.authenticate()
                print("Authentication successful using saved tokens")
            except Exception as e:
                print(f"Saved authentication expired: {str(e)}")
                print("Opening browser for new authentication...")
                authenticate_user()
        else:
            print("First-time authentication. Opening browser for authorization...")
            authenticate_user()

        # Upload video with retry for authentication failures
        try:
            print(f"Uploading {video_file} to YouTube with title: {title}")
            video_id = uploader.upload(video_file, options)

            print(f"Upload complete for {video_file}")
            print(f"Video ID: {video_id}")
            print(f"Video URL: https://youtu.be/{video_id}")
            return 0

        except Exception as e:
            # Check if it's an authentication error
            error_msg = str(e).lower()
            if "token" in error_msg and (
                "expired" in error_msg
                or "revoked" in error_msg
                or "invalid" in error_msg
            ):
                print(f"Authentication token error: {str(e)}")
                print("Attempting to re-authenticate...")

                # Force re-authentication by removing the oauth.json file
                if os.path.exists("./oauth.json"):
                    os.remove("./oauth.json")
                if os.path.exists(oauth_path):
                    os.remove(oauth_path)

                authenticate_user()

                # Try upload again after re-authentication
                print(f"Retrying upload for {video_file}...")
                video_id = uploader.upload(video_file, options)

                print(f"Upload complete for {video_file}")
                print(f"Video ID: {video_id}")
                print(f"Video URL: https://youtu.be/{video_id}")
                return 0
            else:
                # Not an authentication error, re-raise
                raise

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
