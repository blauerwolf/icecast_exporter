# Etapa de build
FROM golang:alpine AS build

WORKDIR /go/src/icecast_exporter

# Recibe variables de build
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY

# Exporta a la etapa de build
ENV HTTP_PROXY=$HTTP_PROXY \
    HTTPS_PROXY=$HTTPS_PROXY \
    NO_PROXY=$NO_PROXY

RUN apk add --no-cache git

COPY . /go/src/icecast_exporter

RUN go get .

# Etapa final
FROM alpine

# Recibe las mismas variables en runtime
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY

ENV HTTP_PROXY=$HTTP_PROXY \
    HTTPS_PROXY=$HTTPS_PROXY \
    NO_PROXY=$NO_PROXY

COPY --from=build /go/bin/icecast_exporter /icecast_exporter

EXPOSE 9146
USER nobody
ENTRYPOINT ["/icecast_exporter"]
