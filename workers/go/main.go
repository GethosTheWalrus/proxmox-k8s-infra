package main

import (
	"log"
	"os"
	"os/signal"
	"syscall"

	"go.temporal.io/sdk/client"
	"go.temporal.io/sdk/worker"

	"temporal-go-worker/activities"
	"temporal-go-worker/workflows"
)

func main() {
	host := os.Getenv("TEMPORAL_HOST")
	if host == "" {
		host = "temporal-frontend.temporal.svc.cluster.local:7233"
	}

	namespace := os.Getenv("TEMPORAL_NAMESPACE")
	if namespace == "" {
		namespace = "default"
	}

	c, err := client.NewClient(client.Options{
		HostPort:  host,
		Namespace: namespace,
	})
	if err != nil {
		log.Fatalln("Unable to create client", err)
	}
	defer c.Close()

	w := worker.New(c, "go-task-queue", worker.Options{})

	w.RegisterWorkflow(workflows.GoWorkflow)
	w.RegisterActivity(activities.ProcessGo)

	err = w.Start()
	if err != nil {
		log.Fatalln("Unable to start worker", err)
	}

	log.Println("Go worker started")

	// Wait for interrupt signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
	<-sigChan

	w.Stop()
} 