#!/bin/sh

if [ "$1" = "beta" ]; then
    sed -i'' -e 's/74ca4a55-9bac-4658-9713-8ed6ca74ac00/ca32b7ec-0523-4ac7-a53f-eedcf12bfb3d/g' manifest.xml
    sed -i'' -e 's/GoPro Remote/BETA GPR/g' resources/strings/strings.xml
else
    sed -i'' -e 's/ca32b7ec-0523-4ac7-a53f-eedcf12bfb3d/74ca4a55-9bac-4658-9713-8ed6ca74ac00/g' manifest.xml
    sed -i'' -e 's/BETA GPR/GoPro Remote/g' resources/strings/strings.xml
fi

rm manifest.xml-e
rm resources/strings/strings.xml-e