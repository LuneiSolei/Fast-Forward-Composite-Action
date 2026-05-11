FROM mcr.microsoft.com/devcontainers/typescript-node

# Install dependencies for GPG key signing
RUN sudo apt-get update && sudo apt-get install gnupg2 -y
RUN install -d -m 700 -o node -g node /home/node/.gnupg