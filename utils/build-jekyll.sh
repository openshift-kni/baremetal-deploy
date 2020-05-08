#!/bin/bash
# Prepares output to build the website

export NOKOGIRI_USE_SYSTEM_LIBRARIES=true

# Get into the output folder
cd website

# Use jekyll to build site to _site/
bundle exec jekyll build
