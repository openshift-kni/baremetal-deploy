# SCTP on OpenShift

OpenShift Container Platform includes the capability of using (single homed) SCTP connections.
The Stream Control Transmission Protocol (SCTP) is a computer networking communications protocol which operates at the transport layer and serves a role similar to the popular protocols TCP and UDP.

Within the OpenShift Container Platform you can:

- establish single homed pod to pod sctp connections
- expose SCTP ClusterIP Services
- expose SCTP NodePort Services

This is achieved by specifying the `protocol` field to `SCTP` the same way is done with `TCP`.

For example:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: demoserver
  namespace: sctp-demo
  labels:
    app: demoserver
spec:
  selector:
    app: demoserver
  ports:
    - name: demoserver
      protocol: SCTP
      port: 30101
      targetPort: "demoserver"
```

## Enabling SCTP

The `SCTP` protocol is enabled by default in OpenShift. Nothing prevents the creation of Pods exposing SCTP ports.

However, in order to be able to use it some tweaking is necessary. This is because the SCTP kernel module is blacklisted by default.

In order for applications to be able to load the module, two different actions need to be performed:

- unblacklisting the kernel module
- having it loaded at boot time

This can be achieved applying a [machine configuration file](https://github.com/openshift/machine-config-operator) like the one below:

``` yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: load-sctp-module
spec:
  config:
    ignition:
      version: 2.2.0
    storage:
      files:
        - contents:
            source: data:,
            verification: {}
          filesystem: root
          mode: 420
          path: /etc/modprobe.d/sctp-blacklist.conf
        - contents:
            source: data:text/plain;charset=utf-8,sctp
          filesystem: root
          mode: 420
          path: /etc/modules-load.d/sctp-load.conf
```

Please note that the file content is supposed to use the [data url scheme](https://tools.ietf.org/html/rfc2397).

The effect of applying these is:

- unblacklisting the sctp module from `/etc/modprobe.d/sctp-blacklist.conf`
- loading it at boot time by writing it to `/etc/modules-load.d/sctp-load.conf`

## Using it with Kustomize

This manifest can also be used as a base for [Kustomize](https://github.com/kubernetes-sigs/kustomize), providing for example different roles to apply this configuration to.
In that case, a sample patch file could be:

```yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: load-sctp-module
```
