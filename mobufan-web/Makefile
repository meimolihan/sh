BINARY  := mobufan
VERSION ?= 1.0.0
LDFLAGS := -s -w -X main.version=$(VERSION)

.PHONY: build all docker run clean

build:
	CGO_ENABLED=0 go build -trimpath -ldflags "$(LDFLAGS)" -o bin/$(BINARY) .

# 交叉编译（使用 Docker 官方 golang 镜像，无需本地安装 Go）
linux-amd64:
	docker run --rm -v "$$PWD":/build -w /build golang:1.22-alpine \
		sh -c 'GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -trimpath -ldflags "$(LDFLAGS)" -o bin/mobufan-linux-amd64 .'

linux-arm64:
	docker run --rm -v "$$PWD":/build -w /build golang:1.22-alpine \
		sh -c 'GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -trimpath -ldflags "$(LDFLAGS)" -o bin/mobufan-linux-arm64 .'

linux-armv7:
	docker run --rm -v "$$PWD":/build -w /build golang:1.22-alpine \
		sh -c 'GOOS=linux GOARCH=arm GOARM=7 CGO_ENABLED=0 go build -trimpath -ldflags "$(LDFLAGS)" -o bin/mobufan-linux-armv7 .'

darwin-amd64:
	docker run --rm -v "$$PWD":/build -w /build golang:1.22-alpine \
		sh -c 'GOOS=darwin GOARCH=amd64 CGO_ENABLED=0 go build -trimpath -ldflags "$(LDFLAGS)" -o bin/mobufan-darwin-amd64 .'

darwin-arm64:
	docker run --rm -v "$$PWD":/build -w /build golang:1.22-alpine \
		sh -c 'GOOS=darwin GOARCH=arm64 CGO_ENABLED=0 go build -trimpath -ldflags "$(LDFLAGS)" -o bin/mobufan-darwin-arm64 .'

windows-amd64:
	docker run --rm -v "$$PWD":/build -w /build golang:1.22-alpine \
		sh -c 'GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build -trimpath -ldflags "$(LDFLAGS)" -o bin/mobufan-windows-amd64.exe .'

all: linux-amd64 linux-arm64 linux-armv7 darwin-amd64 darwin-arm64 windows-amd64

docker:
	docker build --build-arg VERSION=$(VERSION) -t mobufan:$(VERSION) .
	docker tag mobufan:$(VERSION) mobufan:latest

run: build
	./bin/$(BINARY) -listen :2413

clean:
	rm -rf bin
