using Temporalio.Client;
using Temporalio.Worker;
using Temporalio.Activities;
using Temporalio.Workflows;

namespace TemporalWorker;

[Workflow]
public class CSharpWorkflow
{
    [WorkflowRun]
    public async Task<string> RunAsync(string name)
    {
        return $"Hello from C# worker, {name}!";
    }
}

public static class ProcessActivities
{
    [Activity]
    public static string ProcessCSharp(string message, string language)
    {
        return $"C# says: {message}";
    }
}

class Program
{
    static async Task Main(string[] args)
    {
        var client = await TemporalClient.ConnectAsync(
            Environment.GetEnvironmentVariable("TEMPORAL_HOST") ?? "temporal-frontend.temporal.svc.cluster.local:7233"
        );

        using var worker = new TemporalWorker(
            client,
            new TemporalWorkerOptions
            {
                TaskQueue = "csharp-task-queue",
                Namespace = Environment.GetEnvironmentVariable("TEMPORAL_NAMESPACE") ?? "default"
            }
        );

        worker.AddWorkflow<CSharpWorkflow>();
        worker.AddActivity(ProcessActivities.ProcessCSharp);

        Console.WriteLine("C# worker started");
        await worker.RunAsync();
    }
} 