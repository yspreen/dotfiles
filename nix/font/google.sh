#!/bin/bash

# Usage: ./download-font.sh [font-name] (family-name) (variable) (out-dir)
download_google_font() {
    local font_name=$1
    local family_name=$1 # Default to font_name
    local font_params=":wght@100;200;300;400;500;600;700;800;900"
    local agent="curl/7.68.0"
    local out_dir="./font_files/"
    shift

    # Handle remaining args in the correct order
    if [ -n "$1" ] && [ "$1" != "variable" ]; then
        family_name=$1
        shift
    fi

    # Now check for variable flag and output dir
    while [ -n "$1" ]; do
        if [ "$1" = "variable" ]; then
            font_params=":ital,wght@0,300..900;1,300..900&display=swap"
            agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36"
        else
            out_dir="$1"
        fi
        shift
    done

    local temp_dir=$(mktemp -d)
    local css_url="https://fonts.googleapis.com/css2?family=${font_name}${font_params}"

    # Check if curl is installed
    if ! command -v curl &>/dev/null; then
        echo "Error: curl is not installed"
        exit 1
    fi

    # Download CSS file and store its content
    echo "Downloading font CSS file..."
    css_content=$(curl -s -A "$agent" "$css_url")

    if [ -z "$css_content" ]; then
        echo "Error: Could not download CSS content. Check if the font name is correct."
        echo curl -s -A \""$agent"\" \""$css_url"\"
        echo "$css_content"
        rm -rf "$temp_dir"
        exit 1
    fi

    # Create fonts directory if it doesn't exist
    mkdir -p "$out_dir"

    # Download each font file by parsing CSS @font-face blocks
    echo "Downloading font files..."
    IFS='}' read -rd '' -a blocks <<<"$css_content"
    for block in "${blocks[@]}"; do
        if [[ "$block" == *@font-face* ]]; then
            font_family=$(echo "$block" | grep "font-family" | sed "s/.*'\(.*\)'.*/\1/")
            font_style=$(echo "$block" | grep "font-style" | sed "s/.*: *\([^;]*\);.*/\1/")
            font_weight=$(echo "$block" | grep "font-weight" | sed "s/.*: *\([^;]*\);.*/\1/")
            # Use sed instead of grep -oP to extract URL
            url=$(echo "$block" | sed -n "s/.*url(\([^)]*\)).*/\1/p")
            # Provide reasonable fallbacks
            [ -z "$font_family" ] && font_family="unknown"
            [ -z "$font_style" ] && font_style="normal"
            [ -z "$font_weight" ] && font_weight="400"
            base_name="${font_family}_${font_style}_${font_weight}"
            # Replace spaces in base_name with underscores
            base_name=$(echo "$base_name" | tr ' ' '_')
            ext="${url##*.}"
            file_name="${base_name}.${ext}"
            # Resolve name collisions
            counter=2
            while [ -f "$out_dir$file_name" ]; do
                file_name="${base_name}_${counter}.${ext}"
                counter=$((counter + 1))
            done
            echo "Downloading $file_name..."
            if [ -n "$url" ] && curl -s -L "$url" -o "$out_dir$file_name"; then
                echo "Successfully downloaded: $file_name"
            else
                echo "Error downloading: $file_name"
            fi
        fi
    done

    local script_dir=$(pwd)
    cd "$out_dir"

    # find woff2 files:
    woff2_files=$(find . -type f -name "*.woff2")
    if [ -n "$woff2_files" ]; then
        echo "Converting woff2 files to ttf..."
        for woff2_file in $woff2_files; do
            ttf_file="${woff2_file%.woff2}.ttf"

            echo "Converting $woff2_file to $ttf_file..."
            woff2_decompress "$woff2_file"
            rm "$woff2_file"
        done
    fi

    # Rename files to family_name
    if [ -n "$family_name" ]; then
        echo "Renaming files to $family_name..."
        for file in $(find . -type f -name "*.ttf"); do
            python "$script_dir/rename.py" "$file" "$family_name"
        done
    fi

    # Cleanup
    rm -rf "$temp_dir"
    echo "Download complete. Files saved in $out_dir"
}

download_google_font "$@"
