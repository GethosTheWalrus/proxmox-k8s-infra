import asyncio
import os
from dotenv import load_dotenv
from temporalio.client import Client
from temporalio.worker import Worker
from activities import process_python
from workflows import PythonWorkflow

# Load environment variables
load_dotenv()

async def main():
    # Create client connected to server at the specified address
    client = await Client.connect(
        os.getenv("TEMPORAL_HOST", "temporal-frontend.temporal.svc.cluster.local:7233"),
        namespace=os.getenv("TEMPORAL_NAMESPACE", "default")
    )

    # Run the worker
    async with Worker(
        client,
        task_queue="python-task-queue",
        workflows=[PythonWorkflow],
        activities=[process_python],
    ):
        print("Python worker started")
        await asyncio.Event().wait()  # run forever

if __name__ == "__main__":
    asyncio.run(main()) 