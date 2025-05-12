package workflows

import "go.temporal.io/sdk/workflow"

func GoWorkflow(ctx workflow.Context, name string) (string, error) {
	return "Hello from Go worker, " + name + "!", nil
} 