## How to enable SCTP on OCP 4.3

### Load the sctp kernel module

The SCTP module is blacklisted by default, so in order to use it we need to unblacklist it and load it at boot time.

This is achieved by the Machine Config configuration file [sctp_module_mc.yaml](./sctp_module_mc.yaml).

### Temporary issues

At the time of writing, selinux won't allow to open sctp sockets nor to establish sctp connections.
In order to allow that, a custom policy must be applied. This can be achieved by running the daemonset described under
[policy](./policy).
