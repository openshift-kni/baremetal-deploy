#!/bin/bash
# Builds documentation for each release in both HTML and PDF versions

sh utils/build.sh

myreleases=$(cat website/_data/releases.yml | grep release | cut -d ":" -f 2- | sort -u -r)
mydocs=$(cat website/_data/releases.yml | grep name | cut -d ":" -f 2- | sort -u)

mystaticreleases=$(cat website/_data/static.yml | grep release | cut -d ":" -f 2- | sort -u -r)
mystaticdocs=$(cat website/_data/static.yml | grep name | cut -d ":" -f 2- | sort -u)

# Empty index
>website/index.html

# Versioned documents
echo "<ul>" >>website/index.html
for release in ${myreleases}; do
    for doc in ${mydocs}; do
        echo "<li><a href=\"${release}/${doc}\">${release}-${doc}</a></li>" >>website/index.html
    done
done

echo "</ul>" >>website/index.html

# Static documents
echo "<ul>" >>website/index.html
for release in ${mystaticreleases}; do
    for doc in ${mystaticdocs}; do
        echo "<li><a href=\"${release}/${doc}\">${release}-${doc}</a></li>" >>website/index.html
    done
done

echo "</ul>" >>website/index.html
