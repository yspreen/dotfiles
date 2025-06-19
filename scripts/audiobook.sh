#!/usr/bin/env bash
#
# make-m4b.sh
#
# Merge all .mp3 files in the current directory into one .m4b.
# Optional flags (may appear in any order):
#   -i URL       cover image (remote) – resized to 1024×1024 JPEG @ 70 %
#   -t "Title"   audiobook title
#   -a "Author"  audiobook author / artist
#
# Host requirement: nix-shell. All other tools run inside Nix sandboxes.

set -euo pipefail
shopt -s nullglob

###############################################################################
# 1  Parse flags                                                              #
###############################################################################
cover_url=""
title=""
author=""

while getopts ":i:t:a:" opt; do
    case "$opt" in
    i) cover_url=$OPTARG ;;
    t) title=$OPTARG ;;
    a) author=$OPTARG ;;
    \?)
        echo "Usage: $0 [-i URL] [-t \"Title\"] [-a \"Author\"]" >&2
        exit 1
        ;;
    esac
done
shift $((OPTIND - 1))

###############################################################################
# 2  Collect & sort MP3s                                                      #
###############################################################################
mp3s=(*.mp3)
((${#mp3s[@]})) || {
    echo "❌  No .mp3 files found."
    exit 1
}
IFS=$'\n' mp3s=($(printf '%s\n' "${mp3s[@]}" | sort -V))
unset IFS

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
list_file="$tmpdir/concat.txt"
for f in "${mp3s[@]}"; do
    printf "file '%s'\n" "$PWD/$f" >>"$list_file"
done

###############################################################################
# 3  Optional cover image                                                     #
###############################################################################
cover_args=()
if [[ -n $cover_url ]]; then
    orig="$tmpdir/orig.img"
    cover="$tmpdir/cover.jpg"

    nix-shell -p curl --run "curl -fsSL '$cover_url' -o '$orig'"
    nix-shell -p imagemagick --run "
    magick '$orig' -auto-orient \
                   -resize 1024x1024^ \
                   -gravity center -extent 1024x1024 \
                   -quality 70 '$cover'
  "

    cover_args+=(
        -i "$cover"       # second input = cover
        -map 0:a -map 1:v # audio stream + attached pic
        -c:v:0 mjpeg
        -metadata:s:v title="Cover"
        -disposition:v:0 attached_pic
    )
fi

###############################################################################
# 4  Metadata                                                                 #
###############################################################################
meta_args=()
[[ -n $title ]] && meta_args+=(-metadata "title=$title" -metadata "album=$title")
[[ -n $author ]] && meta_args+=(-metadata "artist=$author" -metadata "album_artist=$author")

###############################################################################
# 5  Assemble FFmpeg command                                                  #
###############################################################################
outfile="$(basename "$PWD").m4b"

ffmpeg_cmd=(
    ffmpeg -hide_banner -loglevel error
    -f concat -safe 0 -i "$list_file"
    "${cover_args[@]}"
    -map_metadata -1 # strip incoming tags
    "${meta_args[@]}"
    -c:a aac -b:a 64k -movflags +faststart
    "$outfile"
)

printf -v ffmpeg_str '%q ' "${ffmpeg_cmd[@]}"

###############################################################################
# 6  Run inside nix-shell                                                     #
###############################################################################
nix-shell -p ffmpeg --run "$ffmpeg_str"

echo "✅  Created: $outfile"
