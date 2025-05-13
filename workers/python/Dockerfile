FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV TEMPORAL_HOST=temporal-frontend.temporal.svc.cluster.local:7233
ENV TEMPORAL_NAMESPACE=default

CMD ["python", "worker.py"] 