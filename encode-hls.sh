#!/usr/bin/env bash
# encode-hls.sh - encode a video into a multi-bitrate HLS bundle.
#
# Usage:
#   ./encode-hls.sh <input> <slug>
#
# Output:
#   ./out/<slug>/
#     master.m3u8        # adaptive playlist (3 quality variants)
#     v0/playlist.m3u8   # 360p ~700kbps, for slow 3G
#     v1/playlist.m3u8   # 720p ~2 Mbps, for LTE / decent wifi
#     v2/playlist.m3u8   # 1080p ~4 Mbps, for fast connections
#     v{0,1,2}/seg_*.ts  # video segments (2s each)
#     thumbnail.jpg      # poster frame, 1280px wide, grabbed at 2s
#
# Requires ffmpeg + ffprobe in PATH.

set -eo pipefail

if [[ $# -ne 2 ]]; then
	echo "usage: $0 <input.mp4> <slug>" >&2
	exit 1
fi

input="$1"
slug="$2"

if [[ ! -f "$input" ]]; then
	echo "error: input file not found: $input" >&2
	exit 1
fi

if [[ ! "$slug" =~ ^[a-z0-9-]+$ ]]; then
	echo "error: slug must match [a-z0-9-]+ (got: $slug)" >&2
	exit 1
fi

for tool in ffmpeg ffprobe; do
	if ! command -v "$tool" >/dev/null; then
		echo "error: $tool not found in PATH (brew install ffmpeg)" >&2
		exit 1
	fi
done

out="out/$slug"
mkdir -p "$out/v0" "$out/v1" "$out/v2"

# Detect whether the source has an audio stream. HLS doesn't allow a
# var_stream_map entry to reference a missing stream, so we vary the command.
has_audio=$(
	ffprobe -v error -select_streams a:0 -show_entries stream=index \
		-of csv=p=0 "$input" || true
)

if [[ -n "$has_audio" ]]; then
	# One audio copy per variant: ffmpeg refuses to share a stream between
	# variants.
	audio_args=(
		-map "a:0" -map "a:0" -map "a:0"
		-c:a aac -b:a 128k -ac 2
	)
	var_stream_map="v:0,a:0 v:1,a:1 v:2,a:2"
else
	audio_args=()
	var_stream_map="v:0 v:1 v:2"
fi

ffmpeg -hide_banner -loglevel error -stats -stats_period 30 -y -i "$input" \
	-filter_complex \
		"[0:v]format=yuv420p,split=3[v0in][v1in][v2in]; \
		 [v0in]scale=-2:360[v0out]; \
		 [v1in]scale=-2:720[v1out]; \
		 [v2in]scale=-2:1080[v2out]" \
	\
	-map "[v0out]" -c:v:0 libx264 -profile:v:0 main -preset veryfast -crf 23 -maxrate:v:0 700k -bufsize:v:0 1400k \
	-map "[v1out]" -c:v:1 libx264 -profile:v:1 main -preset veryfast -crf 22 -maxrate:v:1 2000k -bufsize:v:1 4000k \
	-map "[v2out]" -c:v:2 libx264 -profile:v:2 high -preset veryfast -crf 22 -maxrate:v:2 4000k -bufsize:v:2 8000k \
	"${audio_args[@]}" \
	\
	-f hls \
	-hls_time 2 \
	-hls_playlist_type vod \
	-hls_segment_type mpegts \
	-hls_segment_filename "$out/v%v/seg_%03d.ts" \
	-master_pl_name master.m3u8 \
	-var_stream_map "$var_stream_map" \
	"$out/v%v/playlist.m3u8"

# Poster frame at t=2s, 1280px wide, JPEG quality 3.
ffmpeg -hide_banner -loglevel error -y -ss 2 -i "$input" -frames:v 1 -vf "scale=1280:-2" -q:v 3 \
	"$out/thumbnail.jpg"

echo "Done: $out/"
