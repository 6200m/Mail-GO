FROM golang:1.11.4-alpine3.8 as builder-assets

# We assume only git is needed for all dependencies.
# openssl is already built-in.
RUN apk add -U --no-cache git
ENV GO111MODULE=on

# Cache runtime image for later usage.
FROM alpine:3.8 as runtime-assets

ENV DOCKERIZE_VERSION v0.6.1
RUN wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz -O /tmp/dockerize.tar.gz \
    && tar -C /usr/local/bin -xzvf /tmp/dockerize.tar.gz && rm /tmp/dockerize.tar.gz
RUN apk add -U --no-cache ca-certificates


FROM builder-assets as builder
WORKDIR /go/src/github.com/Disconnect24/Mail-GO
COPY go.mod .
COPY go.sum .
RUN go mod download

# Copy necessary parts of the Mail-GO source into builder's source
COPY *.go ./
COPY patch patch
COPY utilities utilities

# Build to name "app".
RUN CGO_ENABLED=0 go build -o app .

FROM runtime-assets as runtime

WORKDIR /go/src/github.com/Disconnect24/Mail-GO/
COPY --from=builder /go/src/github.com/Disconnect24/Mail-GO/ .

# Wait until there's an actual MySQL connection we can use to start.
CMD ["dockerize", "-wait", "tcp://database:3306", "-timeout", "60s", "/go/src/github.com/Disconnect24/Mail-GO/app"]
