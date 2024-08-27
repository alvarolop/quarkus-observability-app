FROM registry.redhat.io/openshift4/ose-cli-rhel9:latest

# Install dependencies
RUN yum install -y unzip

# Install AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install
