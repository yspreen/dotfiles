#!/bin/bash

to_local() {
    # 2025-03-13 8:06:24 AM
    datetime="$1"

    # Convert UTC time to local time using Python
    python3 -c "
import datetime
from datetime import datetime as dt
from datetime import timezone

# Parse input datetime
input_datetime = dt.strptime('$datetime', '%Y-%m-%d %I:%M:%S %p')

# Assume the input time is in UTC
input_datetime_utc = input_datetime.replace(tzinfo=timezone.utc)

# Convert to local timezone
local_datetime = input_datetime_utc.astimezone()

# Format back to the same format
print(local_datetime.strftime('%Y-%m-%d %I:%M:%S %p'))
"
}

# Script to process MOV files in the current directory:
# 1. Rotate vertical videos 90 degrees (if vertical)
# 2. Add date time overlay based on file creation
# 3. Install all required dependencies

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install dependencies
install_dependencies() {
    echo "Checking and installing dependencies..."

    # Check if Homebrew is installed
    if ! command_exists brew; then
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    # Install ffmpeg if not already installed
    if ! command_exists ffmpeg; then
        echo "Installing ffmpeg..."
        brew install ffmpeg
    fi

    # Install exiftool if not already installed
    if ! command_exists exiftool; then
        echo "Installing exiftool..."
        brew install exiftool
    fi
}

# Process video files
process_videos() {
    echo "Processing video files..."

    # Create output directory if it doesn't exist
    mkdir -p processed

    # Find all MOV files in current directory
    for file in *.MOV *.mov; do
        # Skip if no files found
        [ -e "$file" ] || continue

        echo "Processing $file..."
        output_file="processed/processed_$file"

        # Get video dimensions to check if vertical
        width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$file")
        height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$file")

        # Get macOS file creation date
        echo "Getting creation date for $file..."
        creation_date=$(mdls -name kMDItemFSCreationDate -raw "$file")
        if [ $? -ne 0 ] || [ -z "$creation_date" ]; then
            echo "ERROR: Failed to get creation date for $file"
            echo "mdls output: $(mdls -name kMDItemFSCreationDate "$file")"
            continue
        fi

        # Format the date to remove timezone information
        creation_date=$(echo "$creation_date" | sed 's/ +.*//')
        echo "Using creation date: $creation_date"
        creation_date=$(to_local "$creation_date")
        echo "Using creation date local: $creation_date"

        # Get Unix timestamp for creation date
        unix_timestamp=$(date -j -f "%Y-%m-%d %I:%M:%S %p" "$creation_date" "+%s")

        # Format the date components for dynamic timestamp display
        base_year=$(date -j -f "%Y-%m-%d %I:%M:%S %p" "$creation_date" "+%Y")
        base_month=$(date -j -f "%Y-%m-%d %I:%M:%S %p" "$creation_date" "+%m")
        base_day=$(date -j -f "%Y-%m-%d %I:%M:%S %p" "$creation_date" "+%d")
        base_hour=$(date -j -f "%Y-%m-%d %I:%M:%S %p" "$creation_date" "+%H")
        base_minute=$(date -j -f "%Y-%m-%d %I:%M:%S %p" "$creation_date" "+%M")
        base_second=$(date -j -f "%Y-%m-%d %I:%M:%S %p" "$creation_date" "+%S")

        # Create timestamp text with dynamically updating seconds
        timestamp_text="$base_year-$base_month-$base_day $base_hour\\:$base_minute\\:%{eif\\:trunc(mod($base_second+t,60))\\:d\\:2}"

        # Construct filter based on orientation
        if ((width < height)); then
            echo "Vertical video detected, will rotate..."
            filter_chain="transpose=1,drawtext=text='$timestamp_text':x=10:y=10:fontsize=24:fontcolor=white:box=1:boxcolor=black@0.5"
        else
            filter_chain="drawtext=text='$timestamp_text':x=10:y=10:fontsize=24:fontcolor=white:box=1:boxcolor=black@0.5"
        fi

        # Process video with ffmpeg using the constructed filter chain
        ffmpeg -i "$file" \
            -vf "$filter_chain" \
            -metadata comment="Processed with video script" \
            -c:v libx264 -crf 23 \
            -c:a copy \
            "$output_file"

        echo "Saved as $output_file"
    done

    echo "All videos processed."
}

# Main execution
echo "===== MOV Video Processing Script ====="
install_dependencies
process_videos
echo "===== Processing Complete ====="
