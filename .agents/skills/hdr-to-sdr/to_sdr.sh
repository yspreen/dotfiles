#!/bin/zsh
# to_sdr.sh <in.MOV> <out.MOV> [look.cube|-] [ffmpeg input args]
# HLG/HDR iPhone HEVC -> SDR Rec.709, HEVC Main10, using Apple's VideoToolbox tone mapping (scale_vt).
# Optional LUT is applied first in float RGB on the HDR signal, so grade + SDR happen in ONE encode.
# Keeps rotation, all audio tracks, Apple metadata. Retries a busy hardware encoder.
in=$1; out=$2; lut=${3:--}; (( $# >= 3 )) && shift 3 || shift $#
br=$(ffprobe -v error -select_streams v:0 -show_entries stream=bit_rate -of default=nw=1:nk=1 "$in" | head -1); [[ $br == <-> ]] || br=25000000
grade=""; [[ $lut != - ]] && grade="scale=in_range=tv:in_color_matrix=bt2020:out_range=full,format=gbrpf32le,lut3d=file=$lut:interp=tetrahedral,scale=in_range=full:out_color_matrix=bt2020:out_range=tv,"
for try in 1 2 3 4 5; do
  ffmpeg -v error -y -init_hw_device videotoolbox=vt -filter_hw_device vt -noautorotate "$@" -i "$in" \
    -map 0:v:0 -map '0:a?' -map_metadata 0 -movflags use_metadata_tags \
    -vf "${grade}format=p010le,setparams=color_primaries=bt2020:color_trc=arib-std-b67:colorspace=bt2020nc:range=tv,hwupload,scale_vt=color_matrix=bt709:color_primaries=bt709:color_transfer=bt709,hwdownload,format=p010le" \
    -c:v hevc_videotoolbox -profile:v main10 -b:v $(( br * 11 / 10 )) -tag:v hvc1 \
    -color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv -c:a copy "$out" && exit 0
  sleep $(( try * 5 ))
done; exit 1
