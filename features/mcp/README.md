## Rt Worker Machine config pool

This is required in order to apply all machine configs to a set of nodes labelled as rt workers.

### How to run

Tag the nodes as _worker-rt_

For instance, to tag all the nodes but the masters,

```
for node in $(oc get nodes --selector='!node-role.kubernetes.io/master' -o name); do
  oc label $node node-role.kubernetes.io/worker-rt=""
done
```

Then, create the machine config pool

```
oc create -f 00-mcp-worker-rt.yaml
```
