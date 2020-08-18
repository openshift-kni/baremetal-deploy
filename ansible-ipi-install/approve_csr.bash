#!/bin/bash

# Validate there being one arg
if [ $# -ne 1 ]
then
    echo "There should be one arg: the number of workers expected."
    exit 1
fi

echo "Running script to approve CSRs"

export KUBECONFIG=~/clusterconfigs/auth/kubeconfig 

# Loop until the expected number of workers are ready
until [ $(oc get nodes | grep "\bReady\s*worker" | wc -l) == $1 ]
do
    # Search for CSRs awaiting approval
    csr_output=$(oc get csr -ojson | jq -r '.items[] | select(.status == {} ) | .metadata.name')

    # Don't run if empty
    if [ -n "$csr_output" ]
    then
        # Approve
    	echo "$csr_output" | xargs oc adm certificate approve
    fi
    sleep 5
done

echo "Done approving CSRs due to expected number of Ready workers being found"
