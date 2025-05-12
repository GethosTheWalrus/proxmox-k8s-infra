from temporalio import activity

@activity.defn
async def process_python(message: str, language: str) -> str:
    return f"Python says: {message}" 