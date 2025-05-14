using Temporalio.Activities;

public static class Activities
{
    [Activity]
    public static async Task<string> ProcessCSharp(string message)
    {
        return $"C# says: {message}";
    }
} 