#!/bin/bash

UDEV_RULE="ACTION==\"add|change\", ATTRS{device}==\"0x$1\", ENV{NM_UNMANAGED}=\"1\""
BASE64_UDEV_RULE=$(echo "$UDEV_RULE" | base64 -w0)
export BASE64_UDEV_RULE

envsubst < 99-worker-etc-udev-rules-d-11-nm-unmanaged-rules.yaml | oc create -f -