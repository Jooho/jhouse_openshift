# Development Guide

## Setup Development Environment
- clean library
- donwload grpc gen well know type
- install grpc related binaries
~~~
make setup
~~~

## Start Grpc Server
~~~
make run 
~~~

## Compile Proto messages (v1)
~~~
# generate pb files
make gen-v1-proto

# clean pb files
make clean-v1-proto
~~~