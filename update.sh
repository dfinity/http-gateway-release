#!/bin/bash

# Updates ic-gateway to the last release if it's different

RELEASE="release.json"
curl -s https://api.github.com/repos/dfinity/ic-gateway/releases/latest > $RELEASE

OLD_URL=$(jq -r '.["ic-gateway"].url' refs.json)
NEW_URL=$(jq -r '.assets[] | select(.name == "ic-gateway") | .browser_download_url' $RELEASE)
VERSION=$(jq -r '.name' $RELEASE)

rm -f $RELEASE

if [ "$OLD_URL" == "$NEW_URL" ]; then
    exit
fi

NEW_HASH=$(curl -s "${NEW_URL}" | shasum -a 256 | awk '{print $1}')

echo "URL=${NEW_URL}"
echo "HASH=${NEW_HASH}"
echo "VERSION=${VERSION}"

jq ".[\"ic-gateway\"].url = \"${NEW_URL}\" | .[\"ic-gateway\"].sha256 = \"${NEW_HASH}\"" refs.json > refs.json.new
mv refs.json.new refs.json
