# ---- Stage 1: Build ----
FROM golang:1.25-alpine AS builder

# Opcionales: variables de proxy para la fase de build
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY

# Docker solo pasa los ARG si los definís en docker-compose.yml
ENV HTTP_PROXY=$HTTP_PROXY \
    HTTPS_PROXY=$HTTPS_PROXY \
    NO_PROXY=$NO_PROXY

WORKDIR /app

# Copiar dependencias primero para cachear go mod
COPY go.mod go.sum ./
RUN go mod download

# Copiar el resto del código
COPY . .

# Compilar binario estático
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o icecast_exporter .

# ---- Stage 2: Runtime ----
FROM alpine:3.22

# Actualizar sistema y agregar certificados
RUN apk --no-cache upgrade && apk --no-cache add ca-certificates

# Limpiar cualquier variable de proxy (aseguramos runtime sin proxy)
ENV HTTP_PROXY="" \
    HTTPS_PROXY="" \
    FTP_PROXY="" \
    NO_PROXY="" \
    http_proxy="" \
    https_proxy="" \
    ftp_proxy="" \
    no_proxy=""

WORKDIR /root/
COPY --from=builder /app/icecast_exporter .

EXPOSE 9112

CMD ["./icecast_exporter"]
