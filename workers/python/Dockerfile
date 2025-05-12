FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Start both the worker and the main workflow
CMD ["python", "main_workflow.py"] 