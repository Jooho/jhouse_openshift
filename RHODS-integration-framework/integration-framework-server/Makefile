
# Versions
PROTOC_VER=21.2
PROTOC_GEN_GO_GRPC=1.2
PROTOC_GEN_GO=1.28


.PHONY: lib-clean
lib-clean:
	rm -rf protoc3 /tmp/protoc3 /tmp/pkg
	rm -f protoc-${PROTOC_VER}-linux-x86_64.zip
	go clean

.PHONY: lib-install
lib-install:
	go install google.golang.org/protobuf/cmd/protoc-gen-go@v${PROTOC_GEN_GO}
	go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v${PROTOC_GEN_GO_GRPC}

.PHONY: lib-download
lib-download:
	# Protoc download
	curl -OL https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VER}/protoc-${PROTOC_VER}-linux-x86_64.zip
	unzip protoc-${PROTOC_VER}-linux-x86_64.zip  -d /tmp/protoc3
	mkdir protoc3
	mv /tmp/protoc3/include/* protoc3
	rm -f protoc-${PROTOC_VER}-linux-x86_64.zip

.PHONY: setup
setup: lib-clean lib-install 
	make lib-download

.PHONY: gen-v1-protos
gen-v1-proto:
	find ./api/proto/v1 -name "*.proto" | xargs -I % sh -c 'protoc --proto_path=. --proto_path=protoc3 --proto_path=./vendor  --go_out /tmp --go_opt paths=source_relative --go-grpc_out /tmp --go-grpc_opt paths=source_relative %'

	cp -R /tmp/api/proto/* ./pkg/api/
	rm -rf ./pkg/api/proto 
	
	go mod tidy
	go mod vendor
	 
.PHONY: clean-proto
clean-v1-proto: 
	find ./pkg/api/v1/ -name "*.go"  |xargs rm -rf
	rm -rf /tmp/pkg

.PHONY: run
run:
	go run ./cmd/server/main.go