#!/bin/bash
source $(dirname "$(realpath "$0")")/env.sh
jhouse_repo_path=$1

# Check if yq is already installed
if ! command -v yq &> /dev/null || ! yq --version &> /dev/null; then
    echo "yq is not installed. Downloading and installing..."
    
    # You can replace this URL with the latest release URL if needed
    DOWNLOAD_URL="https://github.com/mikefarah/yq/releases/download/3.4.1/yq_linux_amd64"
    FILE_NAME=$(echo $DOWNLOAD_URL| awk -F/ '{print $(NF)}')

    # Download yq binary
    curl -LO "$DOWNLOAD_URL"

    # Make it executable
    chmod +x $FILE_NAME

    # Move it to a directory in your PATH
    sudo mv ${FILE_NAME} /usr/local/bin/yq

    echo "yq has been installed successfully."
else
    echo "yq is already installed."
fi


# Check if jq is already installed
if ! command -v jq &> /dev/null || ! jq --version &> /dev/null; then
    echo "jq is not installed. Downloading and installing..."
    
    # You can replace this URL with the latest release URL if needed
    DOWNLOAD_URL="https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64"
    FILE_NAME=$(echo $DOWNLOAD_URL | awk -F/ '{print $(NF)}')

    # Download jq binary
    curl -LO "$DOWNLOAD_URL"

    # Make it executable
    chmod +x $FILE_NAME

    # Move it to a directory in your PATH
    sudo mv ${FILE_NAME} /usr/local/bin/jq

    echo "jq has been installed successfully."
else
    echo "jq is already installed."
fi

# Check if grpcurl is already installed
if ! command -v grpcurl &> /dev/null || ! jq --version &> /dev/null; then
    echo "grpcurl is not installed. Downloading and installing..."
    
    # You can replace this URL with the latest release URL if needed
    DOWNLOAD_URL="https://github.com/fullstorydev/grpcurl/releases/latest/download/grpcurl_linux_x86_64"
    FILE_NAME=$(echo $DOWNLOAD_URL | awk -F/ '{print $(NF)}')

    # Download grpcurl binary
    curl -LO "$DOWNLOAD_URL"

    # Make it executable
    chmod +x $FILE_NAME

    # Move it to a directory in your PATH
    sudo mv ${FILE_NAME} /usr/local/bin/grpcurl

    echo "grpcurl has been installed successfully."
else
    echo "grpcurl is already installed."
fi

if [[ ! -d $DEMO_HOME ]]; then
  mkdir -p $DEMO_HOME
fi

# Clone jhouse repository
if  [[ ! -d ${DEMO_HOME}/jhouse_openshift ]]; then
  if [[ z$jhouse_repo_path != z ]]; then
    cd ${DEMO_HOME}/
    ln -s $jhouse_repo_path .
  else
    git clone https://github.com/Jooho/jhouse_openshift.git ${DEMO_HOME}/jhouse_openshift
  fi
else
  echo "jhouse_openshift repo exist in the ${DEMO_HOME}"
fi
