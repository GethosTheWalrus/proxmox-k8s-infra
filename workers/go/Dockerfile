FROM golang:1.21-alpine AS builder

WORKDIR /app

# Copy go.mod first to leverage Docker cache
COPY go.mod ./
RUN go mod download

COPY . .
RUN go mod tidy && \
    go build -o worker .

FROM alpine:latest

WORKDIR /app

COPY --from=builder /app/worker .

ENV TEMPORAL_HOST=temporal-frontend.temporal.svc.cluster.local:7233
ENV TEMPORAL_NAMESPACE=default

CMD ["./worker"] 