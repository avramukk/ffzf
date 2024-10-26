#ffmpeg #go #fzf

# ffzf: ffmpeg + fzf

![[Image-26-10-2024.gif]]

Simple CLI tool for fast run test streams with ffmpeg+fzf
# Problem

I often use test streams with ffmpeg and every engineer knows how **ffmpeg syntax sucks**.

I created this CLI tool to run streams from a file or lavfi generator immediately.

You can compile a go binary or use a bash script. Choose what is more convenient for you.

## Dependencies

[fzf](https://github.com/junegunn/fzf)
[ffmpeg](https://github.com/FFmpeg/FFmpeg)

## Installation

Clone repo:
```shell
git clone https://github.com/avramukk/ffzf.git
```

Build binary file.

```shell
go build -o ffzf main.go
```

## Usage

Copy the built binary to your PATH, run it in the terminal, or use the bash script.

```bash
ffzf
```

lavfi input used for video `"testsrc=size={resolution}:rate={fps}" `and for audio `-f lavfi -i "sine=frequency=220:beep_factor=4"` just to be able to listen signal.
![[Image-26-10-2024-1.gif]]
If you need something specific, feel free to fork repo update update scripts. Its pretty simple.

Hope it will be helpful for somebody.
