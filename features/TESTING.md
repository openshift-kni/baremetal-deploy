# How to contribute to tests

## Unit Tests

Unit tests must be local to the various features, and have no external dependencies.
Unit tests are meant to be cheap and fast, for this reason we are not providing a way to execute them individually.

Executing `make unittests` will go through all the features and execute all the tests.

## End to end tests

End to end tests must be added to the functests suite that can be found [here](./functests).

All the code testing the same feature must belong to the same subpackage (see [sctp](./functests/sctp)).

In order to allow ginkgo to find and execute the relevant tests, the package must be imported anonymously in the [test_suite_test.go file](./functests/test_suite_test.go) as per the following example:

```go
_ "github.com/openshift-kni/baremetal-deploy/features/functests/sctp"
```

If the tests related to a given feature are intended to run by default when running the suite, they must be added to the `FEATURES` variable assignement in the [Makefile](./Makefile).

### Note

The name of the test entry point must reflect the name of the feature folder under [features](./features). This will make adding new jobs easier.

Each test must not perform any kind of setup, and test the feature assuming that it's already avaliable in the cluster we are testing against.

## Running the e2e tests for a given set of features

This can be done by running a command like

```bash
FEATURES="sctp ptp" make functests
```

## Deployment

In order to ease the creation of e2e test jobs, each feature should provide a `deploy.sh` script that will apply the given feature to the cluster and will wait for it to be available (i.e. waiting for machine configs to be applied).

If this convention is followed, applying a given set of features will be driven by the same `FEATURES` variable:

```bash
FEATURES="sctp ptp" make deploy
```

## Crafting new CI jobs

New CI jobs must be added to the [openshift/release configuration file](https://github.com/openshift/release/blob/master/ci-operator/config/openshift-kni/baremetal-deploy/openshift-kni-baremetal-deploy-master.yaml#L22).

If the conventions described in this document are applied, an e2e job that will test a single feature will look like:

```yaml
- as: sctp-e2e
  commands: cd features && export FEATURES=sctp && make deploy && make functests
  openshift_installer_src:
    cluster_profile: aws
```

Then the prow job must generated using the prowgen tool and committed in the repo.

### Note

If we want to have this jobs running only when the relevant code is changed, the `run_if_changed` directive must be added to the generated job (and it will be preserved across re-generations of the job):

```yaml
run_if_changed: features/sctp/.*
```

See [this](https://github.com/openshift/release/blob/master/ci-operator/jobs/openshift-kni/baremetal-deploy/openshift-kni-baremetal-deploy-master-presubmits.yaml#L17) as an example.

Also, we may want to have the e2e jobs not disabling tide from merging PRs. As such, we must declare them as `optional: true`.

See [here](https://github.com/openshift/release/blob/master/ci-operator/jobs/openshift-kni/baremetal-deploy/openshift-kni-baremetal-deploy-master-presubmits.yaml#L15) for an example.

## Periodic Jobs

Periodic jobs (TBD yet), will deploy and run all the features contained by default in the `FEATURES` variable of the Makefile.
It will be possible also to add jobs testing only specific combination of those.
