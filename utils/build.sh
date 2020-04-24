#!/bin/bash
# Define the index file
ln -s ipi-install-upstream-master.adoc documentation/index.adoc

# Build the documentation
asciidoctor -a toc=left -b xhtml5 -d book -B documentation/ documentation/index.adoc -D ../output/
