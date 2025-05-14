using Microsoft.Extensions.Logging;
using Temporalio.Client;
using Temporalio.Worker;

// Configure logging
using var loggerFactory = LoggerFactory.Create(builder =>
{
    builder
        .SetMinimumLevel(LogLevel.Information)
        .AddConsole();
});

// Get environment variables or use defaults
var address = Environment.GetEnvironmentVariable("TEMPORAL_ADDRESS") ?? "temporal:7233";
var @namespace = Environment.GetEnvironmentVariable("TEMPORAL_NAMESPACE") ?? "default";

// Create client
var client = await TemporalClient.ConnectAsync(new()
{
    TargetHost = address,
    Namespace = @namespace,
    LoggerFactory = loggerFactory,
});

// Create worker
var worker = new TemporalWorker(
    client,
    new TemporalWorkerOptions("csharp-task-queue").
        AddActivity(Activities.ProcessCSharp));

// Start worker
await worker.RunAsync(); 