package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

// Exit the program with an error message
func die(message string) {
	fmt.Fprintln(os.Stderr, message)
	os.Exit(1)
}

// Prompt user to select an input source (file or lavfi test source)
func getInput() (string, string) {
	options := []string{"file", "lavfi"}
	inputType := fzfSelect("Select input type: ", options)

	if inputType == "file" {
		inputFile := selectFile()
		return inputFile, "file"
	} else if inputType == "lavfi" {
		return "testsrc2", "lavfi"
	} else {
		die("Invalid input selection.")
	}
	return "", ""
}

// Select a file using ls and fzf
func selectFile() string {
	cmd := exec.Command("sh", "-c", "ls *.mp4 *.mov *.mkv *.avi | fzf --layout=reverse")
	output, err := cmd.Output()
	if err != nil {
		die("No file selected.")
	}
	return strings.TrimSpace(string(output))
}

// Prompt user to select resolution for the output
func getResolution() string {
	options := []string{"1920x1080", "1280x720", "854x480", "640x360", "426x240"}
	return fzfSelect("Select resolution: ", options)
}

// Prompt user to select FPS for the output
func getFPS() string {
	options := []string{"24", "25", "29.97", "30", "50", "59.94", "60"}
	return fzfSelect("Select FPS: ", options)
}

// Prompt user to select bitrate for the output
func getBitrate() string {
	options := []string{"1Mbps", "4Mbps", "6Mbps", "10Mbps", "Custom"}
	choice := fzfSelect("Select bitrate: ", options)
	if choice == "Custom" {
		fmt.Print("Enter custom bitrate (e.g., 2M): ")
		reader := bufio.NewReader(os.Stdin)
		customBitrate, err := reader.ReadString('\n')
		if err != nil {
			die("Failed to read custom bitrate.")
		}
		return strings.TrimSpace(customBitrate)
	} else {
		return strings.Replace(choice, "Mbps", "M", 1)
	}
}

// Prompt user to input the output URL
func getURL() string {
	fmt.Print("Enter output URL (rtmp or srt): ")
	reader := bufio.NewReader(os.Stdin)
	url, err := reader.ReadString('\n')
	if err != nil {
		die("Failed to read URL.")
	}
	url = strings.TrimSpace(url)
	if strings.HasPrefix(url, "rtmp") || strings.HasPrefix(url, "srt") {
		return url
	} else {
		die("Invalid URL format. Must be rtmp or srt.")
	}
	return ""
}

// Main function to drive the script execution
func main() {
	// Get input file or lavfi source
	input, inputType := getInput()

	// Get resolution, FPS, bitrate, and URL
	resolution := getResolution()
	fps := getFPS()
	bitrate := getBitrate()
	url := getURL()

	// Construct the ffmpeg command based on input type
	var ffmpegCmd string
	if inputType == "lavfi" {
		// Lavfi input with testsrc2 and sine audio
		ffmpegCmd = fmt.Sprintf(`ffmpeg -re -stream_loop -1 -f lavfi -i "testsrc=size=%s:rate=%s" `+
			`-f lavfi -i "sine=frequency=220:beep_factor=4" `+
			`-b:v "%s" -profile:v high -pix_fmt yuv420p `+
			`-vf "drawtext=fontsize=150:fontcolor=red:x=(w-tw)/4:y=(h-th)/2:text='%%{pts\\:hms} %%{n}':timecode_rate=%s" `+
			`-c:v libx264 -c:a aac `+
			`-f mpegts "%s"`, resolution, fps, bitrate, fps, url)
	} else {
		// Regular file input
		ffmpegCmd = fmt.Sprintf(`ffmpeg -re -stream_loop -1 -i "%s" -s "%s" -r "%s" -b:v "%s" `+
			`-c:v libx264 -c:a aac -f mpegts "%s"`, input, resolution, fps, bitrate, url)
	}

	// Print the ffmpeg command
	fmt.Println("Starting ffmpeg with command:")
	fmt.Println(ffmpegCmd)

	// Execute the command
	cmd := exec.Command("sh", "-c", ffmpegCmd)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	err := cmd.Run()
	if err != nil {
		die("ffmpeg command failed.")
	}
}

// Utility function to execute fzf with a list of options
func fzfSelect(prompt string, options []string) string {
	cmd := exec.Command("fzf", "--layout=reverse", "--prompt="+prompt)
	stdin, err := cmd.StdinPipe()
	if err != nil {
		die("Failed to create stdin pipe for fzf.")
	}
	go func() {
		defer stdin.Close()
		for _, option := range options {
			fmt.Fprintln(stdin, option)
		}
	}()
	output, err := cmd.Output()
	if err != nil {
		die("fzf selection failed.")
	}
	return strings.TrimSpace(string(output))
}
