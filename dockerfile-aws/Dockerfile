FROM registry.access.redhat.com/ubi9-minimal:latest

# Install EPEL for s3cmd and awscli
RUN rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm

RUN microdnf install -y awscli \
    && microdnf clean all
