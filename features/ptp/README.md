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

## Instructions

* Create a `myvars` file that fits your environment. You can use the [myvars.example](myvars.example) as inspiration.
* Run the `deploy.sh` script

Run the `deploy.sh` script and validate the pods are inplace:
```bash
oc get po -n openshift-ptp
NAME                            READY   STATUS    RESTARTS   AGE
linuxptp-daemon-6xjnq           1/1     Running   0          18m
linuxptp-daemon-fkzxj           1/1     Running   0          18m
linuxptp-daemon-mtpn4           1/1     Running   0          18m
linuxptp-daemon-r7z5d           1/1     Running   0          18m
ptp-operator-7f4d4dddf4-v2xzc   1/1     Running   0          19m
```

## Testing

Run the `test.sh` file. It will label one of the masters randomly to act as the grandmaster,
then it will deploy the ptp config yaml files one for the grandmaster and one for the slaves.


## Deploying unreleased versions

If you want to test a unreleased version of the PTP operator you need to add a new operator source.
In case the operator source is private you will need to provide a secret with the login token.

Login token creation example:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: marketplacesecret
  namespace: openshift-marketplace
type: Opaque
stringData:
    token: "<token>"
```

Then you can create the new operator source using the authorization token that was created before
```yaml
apiVersion: "operators.coreos.com/v1"
kind: "OperatorSource"
metadata:
  name: "opsrctest"
  namespace: "openshift-marketplace"
  labels:
    opsrc-provider: opsrctest
spec:
  authorizationToken:
    secretName:  marketplacesecret
  type: appregistry
  endpoint: "<end-point>"
  registryNamespace: "<registry-namespace>"
  displayName: "opsrctest"
  publisher: "opsrctest"
```
