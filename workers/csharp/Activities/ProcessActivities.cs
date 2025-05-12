using Temporalio.Activities;

namespace TemporalWorker.Activities
{
    public class ProcessActivities
    {
        [Activity]
        public static string ProcessCSharp(string message, string language)
        {
            return $"C# says: {message}";
        }
    }
} 