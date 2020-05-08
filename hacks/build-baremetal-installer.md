# How to build the openshift-baremetal-install binary in RHEL8

Those instructions are intended to show how to compile the `openshift-baremetal-install`
from scratch in RHEL8 in case it is required to apply some PRs.

> WARNING: This is just for testing purposes in case an unmerged PR is needed.

- Install golang and required libs:

```shell
sudo yum install golang-bin gcc-c++ libvirt-devel git -y
```

- Create some folders required for golang (required)
  and to store the `openshift-install` binary (optionally):

```shell
mkdir -p ~/go/{src,bin}
mkdir -p ~/bin/
```

- Setup the environment:

```shell
export GOPATH=${HOME}/go
export PATH="${GOPATH}/bin:${HOME}/bin:$PATH"
```

Optionally, add those to the `~/.bashrc`:

```shell
echo 'export GOPATH=${HOME}/go' >> ~/.bashrc
echo 'export PATH="${GOPATH}/bin:${HOME}/bin:$PATH"' >> ~/.bashrc
```

- Get the sources:

```shell
go get -v -u github.com/openshift/installer
```

- Configure user/email in order to allow `git am` to work:

```shell
pushd ${GOPATH}/src/github.com/openshift/installer
git config user.name foo
git config user.email foo@bar.com
```

- Pull latest just in case:

```shell
git pull
```

- Apply PRs. In this example PRs 1, 2 & 3 (obviously you want to apply the ones you need):

```shell
for pr in 1 2 3; do
  curl -L https://github.com/openshift/installer/pull/${pr}.patch | git am
done
```

- Build the binary:

> NOTE: This will take a while and requires some amount of memory/cpu (tested with 4 GB)

```shell
TAGS="baremetal libvirt" hack/build.sh
```

- Optionally, copy the binary to `${HOME}/bin/` if needed:

```shell
cp bin/openshift-install ${HOME}/bin/
popd
```

If a specific release image is needed, the `OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE` environment
variable can be used as:

```shell
export OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE=myregistry.example.com/ocp/release:TAG"
```

where `TAG=4.3.0-0.ci-2019-11-15-123059` or the required one.
