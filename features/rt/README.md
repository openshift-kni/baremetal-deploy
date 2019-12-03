# Realtime

Here you find realtime feature related manifests.

## RT kernel

The realtime kernel will be installed using MachineConfig, which installs a new systemd unit, which runs a script.
The template for the MC and the script are located in `assets`. The actual manifest is created by running `make rt-kernel-manifest`,
which will base64 encode the script and put it into the template. The result is stored alongside other manifests in `manifests`.