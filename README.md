# OpenShift Baremetal Deploy

This repository is intended to store resources and deployment artifacts
for [bare metal](https://github.com/metal3-io/metal3-docs/blob/master/design/bare-metal-style-guide.md)
OpenShift KNI clusters (currently OpenShift 4.3)

It also contains optional features focused on low-latency workloads, NFV workloads, etc.

## Installation artifacts

- [Installation Steps](https://openshift-kni.github.io/baremetal-deploy/)
- [Installing IPI on BM using the Ansible Playbook](ansible-ipi-install/)
  - Versions: 4.3, 4.4

## Optional features

- [Performance](features/performance/). Performance related features like Hugepages, Real time kernel, CPU Manager and Topology Manager.
- [Bonding](features/bonding/). A helper script to create bonding devices with ignition and/or NMstate.
- [DPDK](features/dpdk/). Example workload that uses DPDK libraries for packet processing.
- [Kubernetes NMstate](features/kubernetes-nmstate/). Node-networking configuration driven by Kubernetes and executed
  by NMstate.
- [PTP](features/ptp). This operator manages cluster wide Precision Time Protocol (PTP) configuration.
- [SCTP](features/sctp). These assets enables Stream Control Transmission Protocol (SCTP) in the RHCOS
  worker nodes.
- [SR-IOV](features/sriov). The SR-IOV Network Operator creates and manages the components of the SR-IOV stack.
- [CNV](features/cnv). Container-native virtualization is an add-on to OpenShift Container Platform that allows you to run and manage virtual machine workloads alongside container workloads.

## Performance tuning

The [Performance Tuning](features/performance) folder contains some assets intended to improve performance such as:

- Huge Pages
- Topology Manager
- CPU manager
- Real time kernel (including a new `worker-rt` Kubernetes/OpenShift node role)

Those assets are applied mainly via the [Node Tuning operator](https://github.com/openshift/cluster-node-tuning-operator)
and/or the [Machine Config](https://github.com/openshift/machine-config-operator) operators.

## How to contribute

See [CONTRIBUTING](CONTRIBUTING.md) for some guidelines.

## To do

- [ ] Additional step for disconnected install
- [ ] Installation Troubleshooting

## Thanks

- Netlify for PR rendering:

  [![](https://www.netlify.com/img/global/badges/netlify-light.svg)](https://www.netlify.com)
