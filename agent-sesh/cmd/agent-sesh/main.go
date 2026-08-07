package main

import (
	"fmt"
	"os"

	"github.com/mattgmak/agent-sesh/internal/debug"
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
		case "debug":
			if len(os.Args) < 3 {
				fmt.Fprintln(os.Stderr, "usage: agent-sesh debug <registry|validate|panes|discover|pane <target>>")
				os.Exit(2)
			}
			switch os.Args[2] {
			case "registry":
				if err := debug.Registry(os.Stdout); err != nil {
					fmt.Fprintln(os.Stderr, err)
					os.Exit(1)
				}
			case "validate":
				if err := debug.Validate(os.Stdout); err != nil {
					fmt.Fprintln(os.Stderr, err)
					os.Exit(1)
				}
			case "panes":
				if err := debug.Panes(os.Stdout); err != nil {
					fmt.Fprintln(os.Stderr, err)
					os.Exit(1)
				}
			case "discover":
				if err := debug.Discover(os.Stdout); err != nil {
					fmt.Fprintln(os.Stderr, err)
					os.Exit(1)
				}
			case "pane":
				if len(os.Args) < 4 {
					fmt.Fprintln(os.Stderr, "usage: agent-sesh debug pane <tmux-target>")
					os.Exit(2)
				}
				if err := debug.Pane(os.Stdout, os.Args[3]); err != nil {
					fmt.Fprintln(os.Stderr, err)
					os.Exit(1)
				}
			default:
				fmt.Fprintln(os.Stderr, "usage: agent-sesh debug <registry|validate|panes|discover|pane <target>>")
				os.Exit(2)
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
