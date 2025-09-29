FROM golang:1.25-alpine AS builder

# Set proxy environment variables for build
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG FTP_PROXY
ARG NO_PROXY
ARG http_proxy
ARG https_proxy
ARG ftp_proxy
ARG no_proxy

ENV HTTP_PROXY=$HTTP_PROXY
ENV HTTPS_PROXY=$HTTPS_PROXY
ENV FTP_PROXY=$FTP_PROXY
ENV NO_PROXY=$NO_PROXY
ENV http_proxy=$http_proxy
ENV https_proxy=$https_proxy
ENV ftp_proxy=$ftp_proxy
ENV no_proxy=$no_proxy

WORKDIR /app
COPY . .
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o icecast_exporter .

FROM alpine:3.22
RUN apk --no-cache upgrade && apk --no-cache add ca-certificates

# Set proxy environment variables for runtime
ENV HTTP_PROXY=""
ENV HTTPS_PROXY=""
ENV FTP_PROXY=""
ENV NO_PROXY=""
ENV http_proxy=""
ENV https_proxy=""
ENV ftp_proxy=""
ENV no_proxy=""

WORKDIR /root/
COPY --from=builder /app/icecast_exporter .
EXPOSE 9112

CMD ["./icecast_exporter"]