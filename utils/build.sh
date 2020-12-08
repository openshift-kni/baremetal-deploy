#!/bin/bash
# Builds documentation for each release in both HTML and PDF versions

# Space separated version list to build
RELEASES="4.4 4.3"

# Devel releases for static documents and devel docs
DEVRELEASE="4.5"

# Versioned documents
DOCS=(
    'Deployment'
)

# Documents using latest
STATIC=(
    'Ansible Playbook Install'
    'Troubleshooting'
    'Ansible Playbook Disconnected Install'
)

DEV=(
    'Deployment'
)

# Get latest version for 'static' documents
LATEST=$(echo ${RELEASES} | tr " " "\n" | sort -V -r | head -1)

build_for_release() {
    doc="${1}"
    release="${2}"
    extraargs="${3}"

    echo "Building documentation doc ${doc} for release ${release}"

    basedir=$(dirname $(readlink "documentation/${doc}.adoc"))
    basefile=$(basename $(readlink "documentation/${doc}.adoc"))

    # Build the documentation
    asciidoctor -a release="${release}" -a toc=left ${extraargs} -b xhtml5 -d book -B "documentation/${basedir}/" "documentation/${basedir}/${basefile}" -o "${doc}.html" -D "../../website/${release}" 2>&1 | grep -v 'Try: gem'
    myrc=${?}

    # Build the documentation PDF
    asciidoctor-pdf -a release="${release}" -a toc=left ${extraargs} -d book -B "documentation/${basedir}/" "documentation/${basedir}/${basefile}" -o "${doc}.pdf" -D "../../website/${release}" 2>&1 | grep -v 'Try: gem'
}

RC=0

# Build all releases
for release in ${RELEASES}; do
    for doc in "${DOCS[@]}"; do
        build_for_release "${doc}" "${release}"
    done
done

# Build latest for static
for release in ${DEVRELEASE}; do
    for doc in "${STATIC[@]}"; do
        build_for_release "${doc}" "${release}"
    done
done

# Build latest for DEVEL
for release in ${DEVRELEASE}; do
    for doc in "${DEV[@]}"; do
        build_for_release "${doc}" "${release}" "-a watermark=True"
    done
done

# Build JSON of generated documentation pages
TARGET="website/_data"
mkdir -p ${TARGET}

# Build HTML page for all generated docs

# Empty file before starting
>${TARGET}/releases.yml
for release in ${RELEASES}; do
    for doc in "${DOCS[@]}"; do
        echo """
${doc}-${release}:
    name: ${doc}
    release: ${release}
    folder: ${release}/${doc}
    """ >>${TARGET}/releases.yml
    done
done

# Empty file before starting
>${TARGET}/static.yml
for release in ${DEVRELEASE}; do
    for doc in "${STATIC[@]}"; do
        echo """
${doc}-${release}:
    name: ${doc}
    release: ${release}
    folder: ${release}/${doc}
    """ >>${TARGET}/static.yml
    done
done

# Empty file before starting
>${TARGET}/devprev.yml
for release in ${DEVRELEASE}; do
    for doc in "${DEV[@]}"; do
        echo """
${doc}-${release}:
    name: ${doc}
    release: ${release}
    folder: ${release}/${doc}
    """ >>${TARGET}/devprev.yml
    done
done

# TODO: CHECK why RC != 0 with no errors website (despite of gem)
RC=0
exit ${RC}
