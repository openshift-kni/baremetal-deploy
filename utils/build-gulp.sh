#!/bin/bash
# Builds documentation for each release in both HTML and PDF versions

sh utils/build.sh

myreleases=$(cat website/_data/releases.yml | grep name | cut -d ":" -f 2- | xargs)

# Empty index
>website/index.html

echo "<ul>" >>website/index.html
for release in ${myreleases}; do
    echo "<li><a href=\"${release}\">${release}</a></li>" >>website/index.html
done

echo "</ul>" >>website/index.html
