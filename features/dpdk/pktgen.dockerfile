FROM quay.io/eminguez/testpmd:latest

ENV DPDK_VER 19.08
ENV DPDK_DIR /usr/src/dpdk-${DPDK_VER}
ENV RTE_TARGET=x86_64-native-linuxapp-gcc
ENV RTE_SDK=${DPDK_DIR}

# Install required packages
# NOTE: python2 and which are for debugging purposes in case dpdk-devbind.py is needed
RUN sed -i -e 's/enabled=0/enabled=1/g' /etc/yum.repos.d/CentOS-PowerTools.repo && \
    yum install git libpcap-devel patch which readline-devel -y && \
    yum install which python2 -y && \
    yum clean all

# Install lua
RUN wget http://www.lua.org/ftp/lua-5.3.4.tar.gz -P /usr/src && \
    tar xzvf /usr/src/lua-5.3.4.tar.gz -C /usr/src && \
    rm -f /usr/src/lua-5.3.4.tar.gz && \
    cd /usr/src/lua-5.3.4 && \
    make linux && make install

# Install pktgen
RUN cd /usr/src && \
    git clone http://dpdk.org/git/apps/pktgen-dpdk && \
    cd /usr/src/pktgen-dpdk && \
    make && \
    cp /usr/src/pktgen-dpdk/app/x86_64-native-linuxapp-gcc/pktgen /usr/local/bin
