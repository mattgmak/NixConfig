package main

import (
	"fmt"
	"os"

	"github.com/mattgmak/agent-sesh/internal/picker"
)

func main() {
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "list":
			if err := picker.List(os.Stdout); err != nil {
				fmt.Fprintln(os.Stderr, err)
				os.Exit(1)
			}
			return
		case "preview":
			if len(os.Args) < 3 {
				fmt.Fprintln(os.Stderr, "usage: agent-sesh preview <session-id>")
				os.Exit(2)
			}
			if err := picker.Preview(os.Stdout, os.Args[2]); err != nil {
				fmt.Fprintln(os.Stderr, err)
				os.Exit(1)
			}
			return
		case "fzf":
			if err := picker.RunFzf(); err != nil {
				fmt.Fprintln(os.Stderr, err)
				os.Exit(1)
			}
			return
		}
	}

	if os.Getenv("AGENT_SESH_FZF") == "1" {
		if err := picker.RunFzf(); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		return
	}

	if err := picker.Run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
