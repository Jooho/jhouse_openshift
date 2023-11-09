#!/bin/bash
source "$(dirname "$0")/env.sh"

./1.setup.sh
./2.generate-cert.sh
./3.deploy-minio.sh
