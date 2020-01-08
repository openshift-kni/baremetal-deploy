# Bonding configuration generation

## Script

* [bonding.py](scripts/bonding.py)
* [Parameters example](examples/parameters.yaml.sample)

## Requirements

* Python >= 3.7 (rpm: python3)
* jinja2 (rpm: python3-jinja2)
* pyyaml (rpm: python3-pyyaml)

## Parameters file

* primary: opens block for Ignition data
  * device: name for the bonding device
  * kernel_options: bonding kernel module parameters
  * phy_devices: array listing the physical devices composing the bond
  * vlans: array listing the VLAN IDs and their network configuration details
* secondary: opens block for NMState data
  * device: name for the bonding device
  * config: opens block for bonding kernel module parameters
    * mode: bonding mode (active-backup, balance-rr, ...)
    * options: dictionary holding key/value parameters (e.g. miimon: 140)
  * phy_devices: array listing the physical devices composing the bond
  * vlans: array listing the VLAN IDs and their network configuration details
  * routes: opens block for routes configuration
    * dst: route destination
    * metric: route metric
    * gw: route gateway
    * iface: route interface
    * table: routing table ID
  * dns: opens block for DNS resolver data
    * search: array listing DNS domain names for looking up short host names
    * nameservers: array listing IP addresses to be used as DNS servers

## Usage

* The parameters file uses two sections, `primary` and `secondary` to define _Ignition_ settings and _NMState_ details respectively
* The script can generate, both _Ignition_ and _NMState_ configuration files at the same time using `-a|--all` or independently, using `-i|--ignition` or `-n|--nmstate`. It does all by default.
* Using the [parameters example](examples/parameters.yaml.sample) as follows:

  ```console
  $ scripts/bonding.py -f examples/parameters.yaml.sample -t templates -o /tmp/out -a
  $ ls -la /tmp/out
  total 8
  drwxrwxr-x.   2 sjr  sjr    80 Dec  4 12:28 .
  drwxrwxrwt. 117 root root 2700 Dec  4 12:28 ..
  -rw-rw-r--.   1 sjr  sjr   899 Dec  4 12:28 2160-nmstate-bonding-manifest.yaml
  -rw-rw-r--.   1 sjr  sjr  1562 Dec  4 12:28 8847-ignition-bond.ign
  ```

  At this point the two files can be used to inject the configuration into the nodes.

## [Bonding using machine-config-operator (MCO)](./examples/mco-bonding.md)
