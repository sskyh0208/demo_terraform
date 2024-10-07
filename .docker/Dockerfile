FROM --platform=linux/amd64 python:3.12

RUN apt-get update
RUN apt-get install -y jq wget gettext zip less vim git

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
RUN unzip awscliv2.zip
RUN ./aws/install

RUN wget https://releases.hashicorp.com/terraform/1.8.0/terraform_1.8.0_linux_amd64.zip && \
    unzip ./terraform_1.8.0_linux_amd64.zip -d /usr/local/bin/

COPY ./requirements.txt /home/terraform/requirements.txt
RUN pip install -r /home/terraform/requirements.txt

WORKDIR /home/terraform/src
