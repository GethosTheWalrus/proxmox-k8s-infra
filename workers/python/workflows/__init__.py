from temporalio.workflow import workflow

@workflow.defn
class PythonWorkflow:
    @workflow.run
    async def run(self, name: str) -> str:
        return f"Hello from Python worker, {name}!" 