FROM centos:latest

ENV DPDK_VER 19.08
ENV DPDK_DIR /usr/src/dpdk-${DPDK_VER}
ENV RTE_TARGET=x86_64-native-linuxapp-gcc
ENV RTE_SDK=${DPDK_DIR}

# Install prerequisite packages
RUN yum groupinstall -y "Development Tools" && \
    yum install --skip-broken -y wget numactl numactl-devel make libibverbs-devel logrotate rdma-core && \
    yum clean all

# Download the DPDK libraries
RUN wget http://fast.dpdk.org/rel/dpdk-${DPDK_VER}.tar.xz -P /usr/src && \
    tar -xpvf /usr/src/dpdk-${DPDK_VER}.tar.xz -C /usr/src && \
    rm -f /usr/src/dpdk-${DPDK_VER}.tar.xz

# Configuration
RUN sed -i -e 's/EAL_IGB_UIO=y/EAL_IGB_UIO=n/' \
      -e 's/KNI_KMOD=y/KNI_KMOD=n/' \
      -e 's/LIBRTE_KNI=y/LIBRTE_KNI=n/' \
      -e 's/LIBRTE_PMD_KNI=y/LIBRTE_PMD_KNI=n/' $DPDK_DIR/config/common_linux && \
    sed -i 's/\(CONFIG_RTE_LIBRTE_MLX5_PMD=\)n/\1y/g' $DPDK_DIR/config/common_base

# Build it
RUN cd ${DPDK_DIR} && \
    make install T=${RTE_TARGET} DESTDIR=${RTE_SDK}

# Build TestPmd
RUN cd ${DPDK_DIR}/app/test-pmd && \
    make && \
    cp testpmd /usr/local/bin/
