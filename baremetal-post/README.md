# WIP / POC !

Demonstrate if / how kustomize can be useful.

## Installation

kustomize installation: https://github.com/kubernetes-sigs/kustomize/blob/master/docs/INSTALL.md

## Usage

KUSTOMIZE_PLUGIN_HOME=$PWD/plugins ./kustomize build --enable_alpha_plugins ./base

## Status of this POC

- demonstrate (using the RT kernel MachineConfig) how to base64 encode a script and place it into a manifest template,
would replaces the generate and deploy script
