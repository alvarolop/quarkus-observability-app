FROM quay.io/openshift/origin-cli:4.16

# Install dependencies
RUN yum install -y unzip

# Install AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install
