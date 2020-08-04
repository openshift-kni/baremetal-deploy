FROM docker.io/centos:centos7
ARG foreman_url=https://foreman.example.com
RUN yum install -y epel-release \
    https://yum.theforeman.org/releases/2.1/el7/x86_64/foreman-release.rpm \
    centos-release-scl-rh \
    rh-ruby25-ruby

RUN yum install -y tfm-rubygem-hammer_cli \
    tfm-rubygem-hammer_cli_foreman

RUN yum install -y python-pip \
    && pip install j2cli

RUN  hammer --fetch-ca-cert ${foreman_url}
COPY foreman.yml.j2 /root/
RUN j2 /root/foreman.yml.j2 > /etc/hammer/cli.modules.d/foreman.yml
