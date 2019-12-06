#!/usr/bin/env python3

import pytest

from testlib import find_yamls


@pytest.mark.parametrize("manifest_tree", find_yamls(__file__, 'MachineConfig'))
def test_machineconfig_kernel_arguments_all_values_set(manifest_tree):
    kargs = manifest_tree['spec']['kernelArguments']
    for karg in kargs:
        items = karg.strip().split('=')
        item_count = len(items)
        if item_count == 2:
            key, value = items
            assert value
        else:
            assert item_count == 1
