#!/bin/bash
# Builds documentation for each release in both HTML and PDF versions

# Space separated version list to build
RELEASES="4.5 4.4 4.3"

build_for_release() {
    release="${1}"

    echo "Building documentation for release ${release}"
    # Build the documentation
    asciidoctor -a release=${release} -a toc=left -b xhtml5 -d book -B documentation/ documentation/index.adoc -D ../website/${release} 2>&1 | grep -v 'Try: gem'
    myrc=${?}

    # Build the documentation PDF
    asciidoctor-pdf -a release=${release} -a toc=left -d book -B documentation/ documentation/index.adoc -D ../website/${release} 2>&1 | grep -v 'Try: gem'
}

# Define the index file
ln -s ipi-install-upstream-master.adoc documentation/index.adoc >/dev/null 2>&1

RC=0

# Build all releases
for release in ${RELEASES}; do
    build_for_release ${release}
done

# Build JSON of generated documentation pages
TARGET="website/_data"
mkdir -p ${TARGET}

# Build HTML page for all generated docs

# Empty file before starting
>${TARGET}/releases.yml
for release in ${RELEASES}; do
    echo """
${release}:
    name: ${release}
    folder: ${release}/
    """ >>${TARGET}/releases.yml
done

# TODO: CHECK why RC != 0 with no errors website (despite of gem)
RC=0
exit ${RC}
