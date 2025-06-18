FROM golang:1.21-alpine AS builder

WORKDIR /app

# Copy Go modules files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY *.go ./

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -o consumer

# Use a small image for the final container
FROM alpine:3.18

WORKDIR /app

# Copy the binary from the builder stage
COPY --from=builder /app/consumer .

# Copy config files
COPY config/config.yaml /app/config/

# Run the application
CMD ["./consumer"]
