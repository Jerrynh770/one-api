# Stage 1: Build frontend assets
FROM --platform=$BUILDPLATFORM node:16 AS builder

WORKDIR /web
COPY ./VERSION .
COPY ./web .

# Build default theme
WORKDIR /web/default
RUN npm install
RUN DISABLE_ESLINT_PLUGIN='true' REACT_APP_VERSION=$(cat VERSION) npm run build

# Build berry theme
WORKDIR /web/berry
RUN npm install
RUN DISABLE_ESLINT_PLUGIN='true' REACT_APP_VERSION=$(cat VERSION) npm run build

# Build air theme
WORKDIR /web/air
RUN npm install
RUN DISABLE_ESLINT_PLUGIN='true' REACT_APP_VERSION=$(cat VERSION) npm run build

# Stage 2: Build Go binary
FROM --platform=$BUILDPLATFORM golang:alpine AS builder2

# Critical fix: Disable CGO for Alpine+ARM64 compatibility
ENV GO111MODULE=on \
    CGO_ENABLED=0 \
    GOOS=linux

WORKDIR /build
ADD go.mod go.sum ./
RUN go mod download

COPY . .
COPY --from=builder /web/build ./web/build

# Build with simplified flags
RUN go build -v -trimpath \
    -ldflags "-s -w -X 'one-api/common.Version=$(cat VERSION)'" \
    -o one-api

# Final stage: Create production image
FROM alpine

RUN apk update && \
    apk upgrade && \
    apk add --no-cache ca-certificates tzdata && \
    update-ca-certificates 2>/dev/null || true

COPY --from=builder2 /build/one-api /
EXPOSE 3000
WORKDIR /data
ENTRYPOINT ["/one-api"]
