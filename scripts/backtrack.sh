#!/bin/bash

# Find all files in the current directory containing 'meeting'
find_backtrack_files() {
    find . -type f -iname "*meeting*" | sort
}

create_black() {
    ffmpeg -f lavfi -i color=c=black:s=640x360 -i "$1" -c:v libx264 -tune stillimage -c:a copy -shortest "$1".black.mp4 # backtrack
}

setup_nix() {
    nix-shell -p python3 --run "python -m venv my-venv"
    nix-shell -p python3 --run "source my-venv/bin/activate; pip install pillar-youtube-upload"
}

cleanup_nix() {
    rm -rf my-venv oauth.json
}

python() {
    nix-shell -p python3 --run "source my-venv/bin/activate; python $*"
}

upload_yt() {
    local video_file="$1"

    echo "Uploading $video_file to YouTube..."

    # Check if credentials file exists
    local credentials="$HOME/.youtube-upload-credentials.json"
    if [ ! -f "$credentials" ]; then
        echo "Error: YouTube credentials not found at $credentials"
        python ~/dotfiles/scripts/setup_youtube_credentials.py
    fi

    export VIDEO_FILE="$video_file"
    python ~/dotfiles/scripts/youtube_uploader.py

    local status=$?
    if [ $status -ne 0 ]; then
        echo "Failed to upload $video_file (error code: $status)"
    fi

    unset VIDEO_FILE
    return $status
}

# Check if an element is in an array
in_array() {
    local needle="$1"
    shift
    local haystack=("$@")
    for item in "${haystack[@]}"; do
        if [[ "$item" == "$needle" ]]; then
            return 0
        fi
    done
    return 1
}

# Main script
main() {
    cd ~/Downloads
    mode="$1"
    [ "$mode" == "upload" ] && setup_nix

    # Get all backtrack files using a more compatible approach
    all_files=()
    while IFS= read -r file; do
        all_files+=("$file")
    done < <(find_backtrack_files)

    if [[ ${#all_files[@]} -eq 0 ]]; then
        echo "No files containing 'meeting' found."
        exit 0
    fi

    # Arrays to store base and suffix files
    base_files=()
    suffix_files=()

    # Categorize files as base or suffix
    for file in "${all_files[@]}"; do
        # continue if file ends with .txt:
        [[ "$file" == *.txt ]] && continue

        base_name=$(basename "$file")

        if [[ "$base_name" =~ _black\.[^.]+$ || "$base_name" =~ \.black\.[^.]+$ ]]; then
            # This is a suffix file
            suffix_files+=("$file")
        else
            # This is a base file
            base_files+=("$file")
        fi
    done

    echo "Found ${#base_files[@]} base files and ${#suffix_files[@]} suffix files."

    # Arrays to track paired files
    paired_base=()
    paired_suffix=()

    for base in "${base_files[@]}"; do
        base_name=$(basename "$base")
        dir_name=$(dirname "$base")
        extension="${base_name##*.}"
        name_without_ext="${base_name%.*}"

        # Check for potential suffix files
        possible_black_1="$dir_name/${name_without_ext}_black.$extension"
        possible_black_2="$dir_name/${name_without_ext}.black.$extension"
        possible_black_3="$dir_name/${name_without_ext}.mp4.black.mp4"
        possible_black_4="$dir_name/${name_without_ext}.m4a.black.mp4"

        count=0
        matched=""

        if in_array "$possible_black_1" "${suffix_files[@]}"; then
            count=$((count + 1))
            matched="$possible_black_1"
        fi

        if in_array "$possible_black_2" "${suffix_files[@]}"; then
            count=$((count + 1))
            matched="$possible_black_2"
        fi

        if in_array "$possible_black_3" "${suffix_files[@]}"; then
            count=$((count + 1))
            matched="$possible_black_3"
        fi

        if in_array "$possible_black_4" "${suffix_files[@]}"; then
            count=$((count + 1))
            matched="$possible_black_4"
        fi

        # Check if we have exactly one match
        if [[ $count -eq 1 ]]; then
            echo "Paired: $base with $matched"
            paired_base+=("$base")
            paired_suffix+=("$matched")
            [ "$mode" == "delete" ] && rm "$base"
        elif [[ $count -gt 1 ]]; then
            echo "Error: $base has more than one suffix counterpart."
            exit 1
        else
            if [ "$mode" == "delete" ]; then
                echo "Error: No suffix file found for $base."
                echo "This should've been created in the previous step."
                exit 1
            fi
            create_black "$base"
        fi
    done

    # Check for suffix files that weren't paired
    for suffix in "${suffix_files[@]}"; do
        if ! in_array "$suffix" "${paired_suffix[@]}"; then
            if [[ "$mode" == "upload" ]]; then
                upload_yt "$suffix" && rm "$suffix"
            fi
        fi
    done

    echo "Pairing complete."

    [ "$mode" == "upload" ] && cleanup_nix
}

main
main delete
main upload
