#!/bin/bash

LOUDNORM_ONLY=0

# Find all files in the current directory containing 'meeting'
find_backtrack_files() {
    find . -type f -iname "*meeting*" | sort
}

print_usage() {
    cat <<EOF
Usage: $(basename "$0") [--loudnorm-only]

Options:
  --loudnorm-only  Normalize matching audio files using loudnorm only
  -h, --help       Show this help message
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --loudnorm-only)
            LOUDNORM_ONLY=1
            ;;
        -h | --help)
            print_usage
            exit 0
            ;;
        *)
            echo "Error: unknown argument: $1"
            print_usage
            exit 1
            ;;
        esac
        shift
    done
}

require_ffmpeg() {
    if ! command -v ffmpeg >/dev/null 2>&1; then
        echo "Error: ffmpeg is required but was not found in PATH."
        echo "Install ffmpeg (or run inside nix-shell -p ffmpeg) and try again."
        exit 1
    fi
}

extract_loudnorm_value() {
    local ffmpeg_output="$1"
    local key="$2"
    printf '%s\n' "$ffmpeg_output" | awk -F'"' -v key="$key" '$2 == key { print $4; exit }'
}

build_sliding_window_norm_filter() {
    local frame_ms="${BACKTRACK_DYN_FRAME_MS:-500}"
    local gauss_size="${BACKTRACK_DYN_GAUSS_SIZE:-31}"
    local max_gain="${BACKTRACK_DYN_MAX_GAIN:-8}"
    local peak="${BACKTRACK_DYN_PEAK:-0.95}"
    local compress="${BACKTRACK_DYN_COMPRESS:-2}"

    # n=0 disables channel coupling so each channel is normalized independently.
    printf 'dynaudnorm=f=%s:g=%s:m=%s:p=%s:s=%s:n=0:c=1' \
        "$frame_ms" "$gauss_size" "$max_gain" "$peak" "$compress"
}

build_youtube_loudnorm_filter() {
    local target_i="${BACKTRACK_YT_TARGET_I:--14}"
    local target_lra="${BACKTRACK_YT_TARGET_LRA:-7}"
    local target_tp="${BACKTRACK_YT_TARGET_TP:--1.5}"
    printf 'loudnorm=I=%s:LRA=%s:TP=%s' "$target_i" "$target_lra" "$target_tp"
}

is_audio_file() {
    local file="$1"
    local extension="${file##*.}"
    local ext_lc
    ext_lc="$(printf '%s' "$extension" | tr '[:upper:]' '[:lower:]')"

    case "$ext_lc" in
    mp3 | m4a | aac | wav | flac | ogg | opus | aif | aiff | mka)
        return 0
        ;;
    *)
        return 1
        ;;
    esac
}

normalize_audio_loudnorm_only() {
    local input_file="$1"
    local extension="${input_file##*.}"
    local ext_lc
    local base_no_ext="${input_file%.*}"
    local output_file
    local loudnorm_base
    local loudnorm_analysis_output
    local measured_i measured_lra measured_tp measured_thresh target_offset
    local audio_filter
    local audio_bitrate="${BACKTRACK_AUDIO_BITRATE:-192k}"

    ext_lc="$(printf '%s' "$extension" | tr '[:upper:]' '[:lower:]')"

    case "$ext_lc" in
    mp3)
        output_file="${base_no_ext}.loudnorm.mp3"
        ;;
    wav)
        output_file="${base_no_ext}.loudnorm.wav"
        ;;
    flac)
        output_file="${base_no_ext}.loudnorm.flac"
        ;;
    *)
        output_file="${base_no_ext}.loudnorm.m4a"
        ;;
    esac

    if [[ -f "$output_file" ]]; then
        echo "$output_file already exists."
        return
    fi

    loudnorm_base="$(build_youtube_loudnorm_filter)"

    loudnorm_analysis_output="$(
        ffmpeg -hide_banner -nostats -i "$input_file" \
            -af "${loudnorm_base}:print_format=json" \
            -f null - 2>&1
    )"

    measured_i="$(extract_loudnorm_value "$loudnorm_analysis_output" "input_i")"
    measured_lra="$(extract_loudnorm_value "$loudnorm_analysis_output" "input_lra")"
    measured_tp="$(extract_loudnorm_value "$loudnorm_analysis_output" "input_tp")"
    measured_thresh="$(extract_loudnorm_value "$loudnorm_analysis_output" "input_thresh")"
    target_offset="$(extract_loudnorm_value "$loudnorm_analysis_output" "target_offset")"

    if [[ -n "$measured_i" && -n "$measured_lra" && -n "$measured_tp" && -n "$measured_thresh" && -n "$target_offset" ]]; then
        audio_filter="${loudnorm_base}:measured_I=${measured_i}:measured_LRA=${measured_lra}:measured_TP=${measured_tp}:measured_thresh=${measured_thresh}:offset=${target_offset}:linear=true"
    else
        echo "Warning: loudnorm analysis did not return expected stats; falling back to one-pass normalization for $input_file."
        audio_filter="${loudnorm_base}:linear=true"
    fi

    case "$ext_lc" in
    mp3)
        ffmpeg -hide_banner -loglevel error -i "$input_file" -af "$audio_filter" \
            -c:a libmp3lame -b:a "$audio_bitrate" "$output_file"
        ;;
    wav)
        ffmpeg -hide_banner -loglevel error -i "$input_file" -af "$audio_filter" \
            -c:a pcm_s16le "$output_file"
        ;;
    flac)
        ffmpeg -hide_banner -loglevel error -i "$input_file" -af "$audio_filter" \
            -c:a flac "$output_file"
        ;;
    *)
        ffmpeg -hide_banner -loglevel error -i "$input_file" -af "$audio_filter" \
            -c:a aac -b:a "$audio_bitrate" -ar 48000 "$output_file"
        ;;
    esac

    touch -r "$input_file" "$output_file"
}

run_loudnorm_only_mode() {
    local all_files=()
    local audio_files=()
    local file
    local base_name

    cd ~/Downloads
    require_ffmpeg

    while IFS= read -r file; do
        all_files+=("$file")
    done < <(find_backtrack_files)

    for file in "${all_files[@]}"; do
        [[ "$file" == *.txt ]] && continue
        base_name="$(basename "$file")"
        [[ "$base_name" =~ _black\.[^.]+$ || "$base_name" =~ \.black\.[^.]+$ ]] && continue
        is_audio_file "$file" && audio_files+=("$file")
    done

    if [[ ${#audio_files[@]} -eq 0 ]]; then
        echo "No audio files containing 'meeting' found."
        return 0
    fi

    echo "Loudnorm-only mode: processing ${#audio_files[@]} audio files."
    for file in "${audio_files[@]}"; do
        normalize_audio_loudnorm_only "$file"
    done
}

create_black() {
    local input_file="$1"
    local output_file="${input_file}.black.mp4"
    local dynamic_filter
    local loudnorm_base
    local analysis_filter
    local loudnorm_analysis_output
    local measured_i measured_lra measured_tp measured_thresh target_offset
    local audio_filter
    local audio_bitrate="${BACKTRACK_AUDIO_BITRATE:-192k}"

    if [[ -f "$output_file" ]]; then
        echo "$output_file already exists."
        return
    fi

    require_ffmpeg
    dynamic_filter="$(build_sliding_window_norm_filter)"
    loudnorm_base="$(build_youtube_loudnorm_filter)"

    analysis_filter="${dynamic_filter},${loudnorm_base}:print_format=json"

    # Two-pass loudness normalization for stable YouTube levels.
    loudnorm_analysis_output="$(
        ffmpeg -hide_banner -nostats -i "$input_file" \
            -af "$analysis_filter" \
            -f null - 2>&1
    )"

    measured_i="$(extract_loudnorm_value "$loudnorm_analysis_output" "input_i")"
    measured_lra="$(extract_loudnorm_value "$loudnorm_analysis_output" "input_lra")"
    measured_tp="$(extract_loudnorm_value "$loudnorm_analysis_output" "input_tp")"
    measured_thresh="$(extract_loudnorm_value "$loudnorm_analysis_output" "input_thresh")"
    target_offset="$(extract_loudnorm_value "$loudnorm_analysis_output" "target_offset")"

    if [[ -n "$measured_i" && -n "$measured_lra" && -n "$measured_tp" && -n "$measured_thresh" && -n "$target_offset" ]]; then
        audio_filter="${dynamic_filter},${loudnorm_base}:measured_I=${measured_i}:measured_LRA=${measured_lra}:measured_TP=${measured_tp}:measured_thresh=${measured_thresh}:offset=${target_offset}:linear=true"
    else
        echo "Warning: loudnorm analysis did not return expected stats; falling back to one-pass normalization for $input_file."
        audio_filter="${dynamic_filter},${loudnorm_base}:linear=true"
    fi

    ffmpeg -hide_banner -loglevel error \
        -f lavfi -i color=c=black:s=640x360 \
        -i "$input_file" \
        -af "$audio_filter" \
        -c:v libx264 -pix_fmt yuv420p -tune stillimage \
        -c:a aac -b:a "$audio_bitrate" -ar 48000 \
        -movflags +faststart \
        -shortest "$output_file" # backtrack

    # Set the modification time of the new file to match the source file
    touch -r "$input_file" "$output_file"
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
        [ -f "$HOME/.youtube-upload-oauth.json" ] && rm "$HOME/.youtube-upload-oauth.json"
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
        possible_black_1="$dir_name/${name_without_ext}_black.mp4"
        possible_black_2="$dir_name/${name_without_ext}.black.mp4"
        possible_black_3="$dir_name/${base_name}.black.mp4"
        possible_black_4="$dir_name/${base_name}_black.mp4"

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
            echo "  $possible_black_1"
            echo "  $possible_black_2"
            echo "  $possible_black_3"
            echo "  $possible_black_4"

            exit 1
        else
            if [ "$mode" == "delete" ]; then
                echo "Error: No suffix file found for $base"
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

parse_args "$@"

if [[ "$LOUDNORM_ONLY" -eq 1 ]]; then
    run_loudnorm_only_mode
    exit 0
fi

main
main delete
main upload
