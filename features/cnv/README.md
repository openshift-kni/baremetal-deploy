# Validating CNV operator

## References
* [Container-native virtualization](https://www.openshift.com/learn/topics/container-native-virtualization/)
* [CNV official documentation](https://docs.openshift.com/container-platform/4.3/cnv/cnv-about-cnv.html)

## Instructions

* Create a `myvars` file that fits your environment. You can use the [myvars.example](myvars.example) as inspiration.
* Run the `deploy.sh` script

The script:

* deploys the CNV operator from the operator hub ([operator namespace](01-cnv-namespace.yaml), [operator group](02-cnv-operatorgroup.yaml) and [subscription](03-cnv-subscription.yaml)).
* creates a [CNV `HyperConverged` object](04-cnv-hcocr.yaml) to deploy container-native virtualization.

### virtctl client

The virtctl client is a command-line utility for managing container-native virtualization resources.
Install the client to your client systems following [the official documentation](https://docs.openshift.com/container-platform/4.3/cnv/cnv_install/cnv-installing-virtctl.html).