#!/bin/bash

source myenv.file

envsubst <  bond1.yaml | oc create -f - 