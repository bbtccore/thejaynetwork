# Build stage
FROM golang:1.24-alpine AS builder

RUN apk add --no-cache \
    git \
    make \
    gcc \
    musl-dev \
    linux-headers

WORKDIR /src

# Cache dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy source and build
COPY . .

RUN make build

# Final stage
FROM alpine:3.20

RUN apk add --no-cache \
    ca-certificates \
    curl \
    jq \
    bash \
    lz4

# Create non-root user
RUN addgroup -S jaynet && adduser -S jaynet -G jaynet

# Copy binary
COPY --from=builder /src/build/jaynd /usr/local/bin/jaynd

# Set ownership
RUN chown -R jaynet:jaynet /usr/local/bin/jaynd

USER jaynet

WORKDIR /home/jaynet

# P2P, RPC, REST API, gRPC, Prometheus
EXPOSE 26656 26657 1317 9090 26660

# Default entrypoint
ENTRYPOINT ["jaynd"]
CMD ["start"]

