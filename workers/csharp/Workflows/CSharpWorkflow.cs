using Temporalio.Workflows;

namespace TemporalWorker.Workflows
{
    [Workflow]
    public class CSharpWorkflow
    {
        [WorkflowRun]
        public async Task<string> RunAsync(string name)
        {
            return $"Hello from C# worker, {name}!";
        }
    }
} 