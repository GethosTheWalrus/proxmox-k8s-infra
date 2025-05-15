using Microsoft.Extensions.Logging;
using Temporalio.Client;
using Temporalio.Worker;

// Create async main
public class Program
{
    public static async Task Main(string[] args)
    {
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

        // Create cancellation token source for graceful shutdown
        using var cts = new CancellationTokenSource();

        // Create worker
        using var worker = new TemporalWorker(
            client,
            new TemporalWorkerOptions("csharp-task-queue").
                AddActivity(Activities.ProcessCSharp));

        try
        {
            // Run worker until cancelled
            Console.WriteLine("Worker starting...");
            await worker.ExecuteAsync(cts.Token);
        }
        catch (OperationCanceledException)
        {
            Console.WriteLine("Worker shutting down...");
        }
    }
} 