import asyncio
import os
from datetime import timedelta
from dotenv import load_dotenv
from temporalio.client import Client
from temporalio.worker import Worker
from temporalio.workflow import workflow
from temporalio import activity

# Load environment variables
load_dotenv()

@workflow.defn
class CrossLanguageWorkflow:
    @workflow.run
    async def run(self, message: str) -> str:
        # Execute activities from each language
        python_result = await workflow.execute_activity(
            "process_python",
            message,
            "python",
            start_to_close_timeout=timedelta(seconds=10),
            task_queue="python-task-queue"
        )

        typescript_result = await workflow.execute_activity(
            "processTypeScript",
            message,
            "typescript",
            start_to_close_timeout=timedelta(seconds=10),
            task_queue="typescript-task-queue"
        )

        csharp_result = await workflow.execute_activity(
            "ProcessCSharp",
            message,
            "csharp",
            start_to_close_timeout=timedelta(seconds=10),
            task_queue="csharp-task-queue"
        )

        go_result = await workflow.execute_activity(
            "ProcessGo",
            message,
            "go",
            start_to_close_timeout=timedelta(seconds=10),
            task_queue="go-task-queue"
        )

        # Combine all results
        return f"""
Original message: {message}
Results from each language:
{python_result}
{typescript_result}
{csharp_result}
{go_result}
"""

async def main():
    # Create client connected to server at the specified address
    client = await Client.connect(
        os.getenv("TEMPORAL_HOST", "temporal-frontend.temporal.svc.cluster.local:7233"),
        namespace=os.getenv("TEMPORAL_NAMESPACE", "default")
    )

    # Run the worker
    async with Worker(
        client,
        task_queue="main-task-queue",
        workflows=[CrossLanguageWorkflow],
    ):
        print("Main workflow worker started")
        await asyncio.Event().wait()  # run forever

if __name__ == "__main__":
    asyncio.run(main()) 