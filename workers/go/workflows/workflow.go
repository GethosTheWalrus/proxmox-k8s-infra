package workflows

import "context"

func GoWorkflow(ctx context.Context, name string) (string, error) {
	return "Hello from Go worker, " + name + "!", nil
} 