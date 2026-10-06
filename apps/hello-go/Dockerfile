# syntax=docker/dockerfile:1
# ---- build stage ----------------------------------------------------------
# ★ LAB (T08 / I04): ベースイメージや VERSION を変えるとイメージの中身とサイズが変わる。
FROM golang:1.23-alpine AS build
WORKDIR /src
COPY go.mod ./
RUN go mod download
COPY . .
ARG VERSION=dev
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags "-s -w -X main.version=${VERSION}" -o /out/hello-go .

# ---- runtime stage --------------------------------------------------------
# distroless/static: シェルもパッケージマネージャもない最小イメージ（攻撃面の縮小）。
# そのため `kubectl exec -- sh` はできない。デバッグは `kubectl debug` を使う（docs/troubleshooting.md）。
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/hello-go /hello-go
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/hello-go"]
