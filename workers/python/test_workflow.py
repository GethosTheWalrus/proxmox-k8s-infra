import asyncio
import os
from dotenv import load_dotenv
from temporalio.client import Client

# Load environment variables
load_dotenv()

async def main():
    # Create client connected to server at the specified address
    client = await Client.connect(
        os.getenv("TEMPORAL_HOST", "temporal-frontend.temporal.svc.cluster.local:7233"),
        namespace=os.getenv("TEMPORAL_NAMESPACE", "default")
    )

    # Start the workflow
    handle = await client.start_workflow(
        "CrossLanguageWorkflow",
        "Hello from the main workflow!",
        id="cross-language-workflow",
        task_queue="main-task-queue"
    )

    # Wait for the workflow to complete
    result = await handle.result()
    print("\nWorkflow completed!")
    print(result)

if __name__ == "__main__":
    asyncio.run(main()) 