#!/bin/bash
# Prepares output to build the website

export NOKOGIRI_USE_SYSTEM_LIBRARIES=true

# Create output folder (should be there)
mkdir -p output/
mkdir -p output/_includes/

# Copy website folder as template to output
rsync -avr website/ output/

# Overwrite repo Gemfile with the one for website
cp output/Gemfile .

# Get into the output folder
cd output

# Install dependencies
gem install bundle
bundle install

# Use jekyll to build site to _site/
jekyll build

# Move the full site back to "./" which is 'output' so that we can publish it
rsync -avr --progress _site/ ./
