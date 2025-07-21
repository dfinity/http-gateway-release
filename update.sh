#!/bin/bash

# Updates the given target to the last release if it's different

TARGET="$1"

RELEASE="release.json"

if [ "${GH_TOKEN}" != "" ]; then
    AUTH_HEADER="Authorization: Bearer ${GH_TOKEN}"
else
    AUTH_HEADER=""
fi

curl -fsSL \
    -H "${AUTH_HEADER}" \
    https://api.github.com/repos/dfinity/${TARGET}/releases/latest > ${RELEASE}

OLD_HASH=$(jq -r ".[\"${TARGET}\"].sha256" refs.json)
NEW_HASH=$(jq -r ".assets[] | select(.name == \"${TARGET}\") | .digest" ${RELEASE} | cut -d':' -f2)
ASSET_ID=$(jq -r ".assets[] | select(.name == \"${TARGET}\") | .id" ${RELEASE})
VERSION=$(jq -r ".tag_name" ${RELEASE})
URL="https://api.github.com/repos/dfinity/${TARGET}/releases/assets/${ASSET_ID}"

rm -f $RELEASE

if [ "${OLD_HASH}" == "${NEW_HASH}" ]; then
    exit
fi

echo "URL=${URL}"
echo "HASH=${NEW_HASH}"
echo "VERSION=${VERSION}"

jq ".[\"${TARGET}\"].url = \"${URL}\" | .[\"${TARGET}\"].sha256 = \"${NEW_HASH}\"" refs.json > refs.json.new
mv refs.json.new refs.json
