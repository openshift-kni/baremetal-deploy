#!/usr/bin/env python3

import configparser

import pytest

from testlib import find_yamls


@pytest.mark.parametrize("manifest_tree", find_yamls(__file__, 'Tuned'))
def test_manifest_tuned_all_values_set(manifest_tree):
    manifest_name = manifest_tree['metadata']['name']
    for profile in manifest_tree['spec']['profile']:
        profile_name = profile['name']
        cfg = configparser.ConfigParser()

        cfg.read_string(profile['data'])
        for section_name, section in cfg.items():
            for key, value in section.items():
                assert value, '%s.%s.%s.%s UNSET' % (
                        manifest_name, profile_name, section_name, key)
