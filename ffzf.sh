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

  # Construct the ffmpeg command based on input type
  if [ "$input_type" == "lavfi" ]; then
    # Lavfi input with testsrc2 and sine audio
    ffmpeg_cmd="ffmpeg -re -stream_loop -1 -f lavfi -i \"testsrc=size=${resolution}:rate=${fps}\" \
      -f lavfi -i \"sine=frequency=220:beep_factor=4\" \
      -b:v \"$bitrate\" -profile:v high -pix_fmt yuv420p \
      -vf \"drawtext=fontsize=150:fontcolor=red:x=(w-tw)/4:y=(h-th)/2:text='%{pts\\:hms} %{n}':timecode_rate=${fps}\" \
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
