#!/usr/bin/env python3

import pytest

from testlib import find_yamls


@pytest.mark.parametrize("manifest_tree", find_yamls(__file__, 'KubeletConfig'))
def test_machineconfig_kernel_arguments_all_values_set(manifest_tree):
    # besides this minimal check, we implicitely check the file
    # is valid YAML. These are the bare minimum tests we can do.
    kubeConf = manifest_tree['spec']['kubeletConfig']
    assert kubeConf['cpuManagerPolicy'] == 'static'
