using Temporalio.Activities;

public static class Activities
{
    [Activity]
    public static string ProcessCSharp(string message)
    {
        return $"C# says: {message}";
    }
} 