#!/bin/bash

# Exit the script with an error message
die() {
  echo "$1" >&2
  exit 1
}

# Prompt user to select an input source (file or lavfi test source)
get_input() {
  local options=("file" "lavfi")
  local choice
  choice=$(printf "%s\n" "${options[@]}" | fzf --layout=reverse --prompt="Select input: ") || die "Input selection failed."

  if [ "$choice" == "file" ]; then
    input_file=$(find . -type f \( -name "*.mp4" -o -name "*.mkv" -o -name "*.mov" \) 2>/dev/null | fzf --layout=reverse --prompt="Select file: ") || die "No file selected."
    echo "$input_file file"
  elif [ "$choice" == "lavfi" ]; then
    echo "testsrc2 lavfi"
  else
    die "Invalid input selection."
  fi
}

# Prompt user to select resolution for the output
get_resolution() {
  local options=("1920x1080" "1280x720" "854x480" "640x360" "426x240")
  resolution=$(printf "%s\n" "${options[@]}" | fzf --layout=reverse --prompt="Select resolution: ") || die "Resolution selection failed."
  echo "$resolution"
}

# Prompt user to select FPS for the output
get_fps() {
  local options=("24" "25" "29.97" "30" "50" "59.94" "60")
  fps=$(printf "%s\n" "${options[@]}" | fzf --layout=reverse --prompt="Select FPS: ") || die "FPS selection failed."
  echo "$fps"
}

# Prompt user to select bitrate for the output
get_bitrate() {
  local options=("1Mbps" "4Mbps" "6Mbps" "10Mbps" "Custom")
  choice=$(printf "%s\n" "${options[@]}" | fzf --layout=reverse --prompt="Select bitrate: ") || die "Bitrate selection failed."

  if [ "$choice" == "Custom" ]; then
    read -rp "Enter custom bitrate (e.g., 2M): " custom_bitrate
    echo "$custom_bitrate"
  else
    echo "${choice/Mbps/M}"
  fi
}

# Prompt user to input the output URL
get_url() {
  local url
  read -rp "Enter output URL (rtmp or srt): " url
  if [[ "$url" == rtmp* ]] || [[ "$url" == srt* ]]; then
    echo "$url"
  else
    die "Invalid URL format. Must be rtmp or srt."
  fi
}

has_ffmpeg_filter() {
  [[ "$(ffmpeg -hide_banner -filters 2>/dev/null)" == *" $1 "* ]]
}

has_ffmpeg_output_protocol() {
  local protocol output_protocols
  protocol="$1"
  output_protocols=$(ffmpeg -hide_banner -protocols 2>/dev/null)
  [[ "$output_protocols" == *$'Output:'*$'\n  '"$protocol"$'\n'* ]]
}

# Main function to drive the script execution
main() {
  # Get input file or lavfi source
  local input input_type
  read -r input input_type <<< "$(get_input)"

  # Get resolution, FPS, bitrate, and URL
  local resolution
  resolution=$(get_resolution)

  local fps
  fps=$(get_fps)

  local bitrate
  bitrate=$(get_bitrate)

  local url
  url=$(get_url)
  local protocol
  protocol="${url%%:*}"
  if ! has_ffmpeg_output_protocol "$protocol"; then
    die "ffmpeg does not support output protocol '$protocol'. Install an ffmpeg build with $protocol support or choose another output URL."
  fi

  # Construct the ffmpeg command based on input type
  if [ "$input_type" == "lavfi" ]; then
    video_filter=""
    if has_ffmpeg_filter "drawtext"; then
      video_filter="-vf \"drawtext=fontsize=150:fontcolor=red:x=(w-tw)/4:y=(h-th)/2:text='%{pts\\:hms} %{n}':timecode_rate=${fps}\""
    else
      echo "Warning: ffmpeg drawtext filter is not available; starting lavfi stream without timestamp overlay." >&2
    fi

    # Lavfi input with testsrc video and sine audio
    ffmpeg_cmd="ffmpeg -re -stream_loop -1 -f lavfi -i \"testsrc=size=${resolution}:rate=${fps}\" \
      -f lavfi -i \"sine=frequency=220:beep_factor=4\" \
      -b:v \"$bitrate\" -profile:v high -pix_fmt yuv420p \
      $video_filter \
      -c:v libx264 -c:a aac \
      -f mpegts \"$url\""
  else
    # Regular file input
    ffmpeg_cmd="ffmpeg -re -stream_loop -1 -i \"$input\" -s \"$resolution\" -r \"$fps\" -b:v \"$bitrate\" \
      -c:v libx264 -c:a aac -f mpegts \"$url\""
  fi

  # Print the ffmpeg command
  echo "Starting ffmpeg with command:"
  echo "$ffmpeg_cmd"

  # Execute the command
  eval "$ffmpeg_cmd" || die "ffmpeg command failed."
}

# Start script
main
