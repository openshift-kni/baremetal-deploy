# Validating PTP operator

## References

* [Precision Time Protocol on Linux ~ Introduction to linuxptp](https://events.static.linuxfound.org/sites/events/files/slides/lcjp14_ichikawa_0.pdf)
* [How to see which clock is which in a ptp configuration](https://access.redhat.com/solutions/4384221)
* [RHEL7 documentation](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/system_administrators_guide/sec-using_ptp)
* [Hybrid Mode PTP: Mixed Multicast and Unicast](https://blog.meinbergglobal.com/2016/08/11/hybrid-mode-ptp-mixed-multicast-unicast/)
* [How to set up PTP in a test environment](https://mojo.redhat.com/docs/DOC-926263)
* [OCP 4.x support for PTP](https://github.com/openshift-telco/ocp4x-ptp)
* [OCP4 PTP Operator](https://github.com/openshift/ptp-operator)
* [ptp4l grand master down with error timed out while polling for tx timestamp](https://access.redhat.com/solutions/2107131)

## TL;DR

* Create a `ptpconfig.yaml` that fits your environment
* Run the `deploy.sh` script

It will deploy the PTP operator and select one of the masters randomly to act as the grandmaster and the other nodes as slaves.

For more instructions, see the [README-manual.md](README-manual.md)
