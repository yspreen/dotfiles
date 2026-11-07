#!/bin/zsh
# grade.sh <in.MOV> <out.MOV> <look.cube> [ffmpeg input args, e.g. -t 5]
# Applies a 3D LUT to iPhone HLG HEVC in float RGB (BT.2020 matrix), keeps HDR (10-bit HLG BT.2020),
# rotation (display matrix), all audio tracks and Apple location/date metadata. Retries busy HW encoder, then software.
in=$1; out=$2; lut=$3; shift 3
br=$(ffprobe -v error -select_streams v:0 -show_entries stream=bit_rate -of default=nw=1:nk=1 "$in" | head -1); [[ $br == <-> ]] || br=25000000
enc() { local sw=$1; shift
  ffmpeg -v error -y -noautorotate "$@" -i "$in" -map 0:v:0 -map '0:a?' -map_metadata 0 -movflags use_metadata_tags \
    -vf "scale=in_range=tv:in_color_matrix=bt2020:out_range=full,format=gbrpf32le,lut3d=file=$lut:interp=tetrahedral,scale=in_range=full:out_color_matrix=bt2020:out_range=tv,format=p010le" \
    -c:v hevc_videotoolbox ${=sw} -profile:v main10 -b:v $(( br * 11 / 10 )) -tag:v hvc1 \
    -color_primaries bt2020 -color_trc arib-std-b67 -colorspace bt2020nc -color_range tv -c:a copy "$out"; }
enc "" "$@" 2>/dev/null || { sleep 5; enc "" "$@" 2>/dev/null; } || enc "-allow_sw 1" "$@"
