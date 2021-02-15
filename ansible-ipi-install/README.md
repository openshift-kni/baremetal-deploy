# Our documentation has moved!

For the latest information on how to install via the Ansible playbook, check out the `Ansible-Playbook-Install` document at <https://openshift-kni.github.io/baremetal-deploy/>

# Repository PR testing

There are two continuous-integration tests connected at this moment that perform a limited testing on the ansible playbook, you can trigger them via:

- Use `[test-ipi]` as a comment in a PR
- Use `check dallas ocp-4.6-vanilla` as a comment in a PR

The results might not be public, but the URL will be pushed as a comment either in reviews requested as result of the test or as a new comment in the PR.
