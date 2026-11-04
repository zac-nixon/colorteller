# syntax=docker/dockerfile:1

# The builder always runs on the host's native platform and cross-compiles
# for the requested target platform, so multi-arch builds don't need emulation.
FROM --platform=$BUILDPLATFORM public.ecr.aws/docker/library/golang:1.27.3 AS builder

ARG GO_PROXY=https://proxy.golang.org
ARG TARGETOS
ARG TARGETARCH

WORKDIR /go/src/github.com/aws/aws-app-mesh-examples/colorapp/teller

# Set the proxies for the go compiler
RUN go env -w GOPROXY=${GO_PROXY}

# go.mod and go.sum go into their own layers.
# This ensures `go mod download` happens only when go.mod and go.sum change.
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -trimpath -ldflags="-s -w" -o /aws-app-mesh-examples-colorapp-teller .

FROM public.ecr.aws/amazonlinux/amazonlinux:2023
RUN dnf update -y && \
    dnf install -y ca-certificates && \
    dnf clean all && \
    rm -rf /var/cache/dnf

COPY --from=builder /aws-app-mesh-examples-colorapp-teller /bin/aws-app-mesh-examples-colorapp-teller

ENTRYPOINT ["/bin/aws-app-mesh-examples-colorapp-teller"]

