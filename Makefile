BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
COMMIT := $(shell git log -1 --format='%H')
APPNAME := thejaynetwork

# do not override user values
ifeq (,$(VERSION))
  VERSION := $(shell git describe --exact-match 2>/dev/null)
  # if VERSION is empty, then populate it with branch name and raw commit hash
  ifeq (,$(VERSION))
    VERSION := $(BRANCH)-$(COMMIT)
  endif
endif

# Update the ldflags with the app, client & server names
ldflags = -X github.com/cosmos/cosmos-sdk/version.Name=$(APPNAME) \
	-X github.com/cosmos/cosmos-sdk/version.AppName=$(APPNAME)d \
	-X github.com/cosmos/cosmos-sdk/version.Version=$(VERSION) \
	-X github.com/cosmos/cosmos-sdk/version.Commit=$(COMMIT)

BUILD_FLAGS := -ldflags '$(ldflags)'

##############
###  Build ###
##############

build:
	@echo "--> Building jaynd binary..."
	@go build $(BUILD_FLAGS) -mod=readonly -o build/jaynd ./cmd/jaynd

build-linux:
	@echo "--> Building jaynd for Linux amd64 (with CosmWasm CGO)..."
	@GOOS=linux GOARCH=amd64 CGO_ENABLED=1 go build -ldflags="-s -w $(ldflags)" -mod=readonly -tags "netgo" -o build/jaynd-linux-amd64 ./cmd/jaynd
	@echo "--> Done. Binary in build/"
	@ls -la build/jaynd-linux-amd64

build-all: build build-linux
	@echo "--> All binaries built."

##############
###  Test  ###
##############

test-unit:
	@echo Running unit tests...
	@go test -mod=readonly -v -timeout 30m ./...

test-race:
	@echo Running unit tests with race condition reporting...
	@go test -mod=readonly -v -race -timeout 30m ./...

test-cover:
	@echo Running unit tests and creating coverage report...
	@go test -mod=readonly -v -timeout 30m -coverprofile=coverage.txt -covermode=atomic ./...
	@go tool cover -html=coverage.txt -o coverage.html
	@rm coverage.txt

bench:
	@echo Running unit tests with benchmarking...
	@go test -mod=readonly -v -timeout 30m -bench=. ./...

test: govet govulncheck test-unit

.PHONY: test test-unit test-race test-cover bench

#################
###  Install  ###
#################

all: install

install:
	@echo "--> ensure dependencies have not been modified"
	@go mod verify
	@echo "--> installing jaynd"
	@go install $(BUILD_FLAGS) -mod=readonly ./cmd/jaynd

.PHONY: all install build

##################
###  Protobuf  ###
##################

proto-deps:
	@echo "Installing proto deps"
	@echo "Proto deps present, run 'go tool' to see them"

proto-gen:
	@echo "Generating protobuf files..."
	@ignite generate proto-go --yes

.PHONY: proto-gen

#################
###  Linting  ###
#################

lint:
	@echo "--> Running linter"
	@go tool github.com/golangci/golangci-lint/cmd/golangci-lint run ./... --timeout 15m

lint-fix:
	@echo "--> Running linter and fixing issues"
	@go tool github.com/golangci/golangci-lint/cmd/golangci-lint run ./... --fix --timeout 15m

.PHONY: lint lint-fix

###################
### Development ###
###################

govet:
	@echo Running go vet...
	@go vet ./...

govulncheck:
	@echo Running govulncheck...
	@go tool golang.org/x/vuln/cmd/govulncheck@latest
	@govulncheck ./...

.PHONY: govet govulncheck

#################
### Docker    ###
#################

docker-build:
	@echo "--> Building Docker image..."
	docker build -t thejaynetwork:$(VERSION) .

docker-push:
	@echo "--> Pushing Docker image..."
	docker push thejaynetwork:$(VERSION)

.PHONY: docker-build docker-push

#################
### Init      ###
#################

init:
	@echo "--> Initializing thejaynetwork node..."
	./build/jaynd init node1 --chain-id thejaynetwork-1
	@echo "--> Done. Edit ~/.jayn/config/genesis.json as needed."

.PHONY: init

