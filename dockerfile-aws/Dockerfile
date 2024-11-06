FROM registry.redhat.io/ubi9-minimal:latest

# Install dependencies
RUN microdnf install -y unzip \
    && microdnf clean all

# Install AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && rm -rf awscliv2.zip \
    && ./aws/install
