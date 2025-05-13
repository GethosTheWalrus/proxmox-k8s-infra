package main

import (
	"context"
	"log"
	"os"
	"time"

	"go.temporal.io/sdk/client"
	"go.temporal.io/sdk/worker"
)

func main() {
	// Create the client object just once per process
	c, err := client.NewClient(client.Options{
		HostPort:  getEnvOrDefault("TEMPORAL_HOST", "temporal-frontend.temporal.svc.cluster.local:7233"),
		Namespace: getEnvOrDefault("TEMPORAL_NAMESPACE", "default"),
	})
	if err != nil {
		log.Fatalln("Unable to create client", err)
	}
	defer c.Close()

	// This worker hosts both Workflow and Activity functions
	w := worker.New(c, "go-task-queue", worker.Options{})

	// Register Workflow and Activity
	w.RegisterWorkflow(GoWorkflow)
	w.RegisterActivity(ProcessGo)

	// Start listening to the Task Queue
	err = w.Run(worker.InterruptCh())
	if err != nil {
		log.Fatalln("Unable to start worker", err)
	}
}

func getEnvOrDefault(key, defaultValue string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return defaultValue
}

func GoWorkflow(ctx context.Context, name string) (string, error) {
	return "Hello from Go worker, " + name + "!", nil
}

func ProcessGo(ctx context.Context, message string, language string) (string, error) {
	return "Go says: " + message, nil
} 