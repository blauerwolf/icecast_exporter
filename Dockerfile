FROM golang:alpine AS build

WORKDIR /go/src/icecast_exporter

ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY

ENV HTTP_PROXY=$HTTP_PROXY \
    HTTPS_PROXY=$HTTPS_PROXY \
    NO_PROXY=$NO_PROXY

RUN apk add --no-cache git

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN go build -o /icecast_exporter .

FROM alpine

COPY --from=build /icecast_exporter /icecast_exporter

EXPOSE 9146
USER nobody
ENTRYPOINT ["/icecast_exporter"]
