package main

import (
	"fmt"
	"os"

	"github.com/Jooho/integration-framework-grpc-server/pkg/cmd"
)

func main() {
	if err := cmd.RunServer(); err != nil {
		fmt.Fprintf(os.Stderr, "%v\n", err)
		os.Exit(1)
	}
}