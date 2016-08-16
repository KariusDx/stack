# Build as: docker build -t aws-stack .
# Run as: docker run --rm -it \
#    -v $PWD:$PWD -w $PWD \
#    -v /tmp:/tmp -v ~/.aws:/root/.aws \
#    -e AWS_SHARED_CREDENTIALS_FILE=/root/.aws/config

FROM python:3.5-slim
RUN pip3 install mypy-lang==0.4 flake8==2.5.4 pyyaml boto3
RUN apt-get update \
  && apt-get install -y curl unzip make \
  && apt-get clean

COPY tools /usr/local/bin
RUN /usr/local/bin/install-zip terraform "https://releases.hashicorp.com/terraform/0.7.0/terraform_0.7.0_linux_amd64.zip"
RUN /usr/local/bin/install-zip packer "https://releases.hashicorp.com/packer/0.10.1/packer_0.10.1_linux_amd64.zip"

ADD . /src

RUN cd /src && make install

ENV AWS_SHARED_CREDENTIALS_FILE /root/.aws/config
