#!/bin/bsh 

# Set the OpenShift version to use.
OPENSHIFT_VERSION=4.14

# Specify the location of the pull secret JSON file.
PULL_SECRET_JSON=~/pull-secret.json

# Check if the pull secret file exists. If it does not, print an error message and exit the script.
if [ ! -f ${PULL_SECRET_JSON} ]; then
  echo "Please download your pull secret from https://console.redhat.com/openshift/install/pull-secret and save it to ${PULL_SECRET_JSON}"
  exit 1
fi

# Check if grpcurl is installed by looking for it in /usr/local/bin. If not found, download and install it.
if [ ! -f /usr/local/bin/grpcurl ];
then 
    # Download the specified version of grpcurl from GitHub.
    curl -OL https://github.com/fullstorydev/grpcurl/releases/download/v1.8.8/grpcurl_1.8.8_linux_x86_64.tar.gz
    
    # Extract the downloaded tar.gz file.
    tar -zxvf grpcurl_1.8.8_linux_x86_64.tar.gz
    
    # Move the grpcurl binary to /usr/local/bin to make it globally accessible.
    sudo mv grpcurl /usr/local/bin/
fi

# Read and decode the Red Hat registry credentials from the pull secret JSON file.
REDHAT_CREDS=$(cat ${PULL_SECRET_JSON} | jq .auths.\"registry.redhat.io\".auth -r | base64 -d)

# Extract the username part of the credentials.
RHN_USER=$(echo $REDHAT_CREDS | cut -d: -f1)

# Extract the password part of the credentials.
RHN_PASSWORD=$(echo $REDHAT_CREDS | cut -d: -f2)

# Log in to the Red Hat registry using the extracted credentials.
podman login -u "$RHN_USER" -p "$RHN_PASSWORD" registry.redhat.io

# Run a container from the Red Hat operator index image on the specified version, exposing port 50051.
podman run -p50051:50051 -d -it registry.redhat.io/redhat/redhat-operator-index:v${OPENSHIFT_VERSION}

# Use grpcurl to connect to the container's GRPC server on localhost:50051 without encryption, 
# and list the available packages, saving the output to a file named packages.out.
grpcurl -plaintext localhost:50051 api.Registry/ListPackages > packages.out

# Parse the package names from the packages.out file and save them to packages.txt.
cat packages.out | jq -r '.packages[] | .name' > packages.txt

# Display the contents of packages.txt, which contains the list of package names.
cat packages.txt
