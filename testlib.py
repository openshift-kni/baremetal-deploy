#!/usr/bin/env python3

import os
import os.path

import yaml


def selfpath(ref):
    return os.path.dirname(os.path.realpath(ref))


def manifest(manif_path):
    with open(manif_path, 'rt') as manif_fd:
        # see https://github.com/yaml/pyyaml/wiki/PyYAML-yaml.load(input)-Deprecation
        # but we trust our own data we generate, don't we?
        return yaml.load(manif_fd, Loader=yaml.FullLoader)


def find_yamls(ref, kind):
    res = []
    basedir = selfpath(ref)
    for dent in os.listdir(basedir):
        print(dent)
        root, ext = os.path.splitext(dent)
        if ext.lower() in ('.yml', '.yaml'):
            fullpath = os.path.join(basedir, dent)
            manifest_tree = manifest(fullpath)
            if manifest_tree['kind'] == kind:
                res.append(manifest_tree)
    return res
