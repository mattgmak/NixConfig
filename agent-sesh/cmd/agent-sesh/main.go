package main

import (
	"fmt"
	"os"

	"github.com/mattgmak/agent-sesh/internal/picker"
)

func main() {
	if err := picker.Run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
