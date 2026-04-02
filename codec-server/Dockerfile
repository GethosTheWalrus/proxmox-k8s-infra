FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod ./
RUN go mod download
COPY main.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -o codec-server .

FROM alpine:3.20
RUN apk --no-cache add ca-certificates
COPY --from=builder /app/codec-server /usr/local/bin/codec-server
EXPOSE 8888
USER 65534:65534
ENTRYPOINT ["codec-server"]
