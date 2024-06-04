#!/bin/bash
# for ubuntu 24.04 only
exec 2>/dev/null

# install dependencies
sudo apt-get install -y nodejs npm 7zip libfuse2t64 icoutils

# set up env vars for later
version="5.3.2"
windows_link="https://music-desktop-application.s3.yandex.net/stable/Yandex_Music_x64_$version.exe"

# make temp dir
mkdir music_tmp
cd music_tmp

# get the exe
echo "Getting $version"
wget -O ym.exe $windows_link

# unpack it
7z x ym.exe
7z x \$PLUGINSDIR/app-64.7z

# get the app.asar out of it and extract
echo "Unpacking app.asar"
cp resources/app.asar ./app.asar
npx --yes @electron/asar extract app.asar ym
cd ym

# ------------------------------
# THE GREAT PATCHENING
# ------------------------------
# remove non available dependencies
sed -i '/chats\/signer/d' package.json
# assign ids to linux version instead of windows one
grep -rlE 'WINDOWS:"[0-9]{8}"' . | xargs sed -i 's/WINDOWS/LINUX/g'
# change the uuids
grep -rlE 'WINDOWS:"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"' . | xargs sed -i 's/WINDOWS/LINUX/g'
# and finally!! change the SECRETKEY!!!!!
grep -rlE '.WINDOWS:[a-zA-Z]{1}="[a-zA-Z0-9]{1,}"' . | xargs sed -i 's/WINDOWS/LINUX/g'
# not necessary but i will still append a platform there :>
grep -rl 'Platform\[\"WINDOWS\"\] = \"win32\"' . | xargs -I {} sed -i '/Platform\[\"WINDOWS\"\] = \"win32\"/a Platform["LINUX"] = "linux";' {}
# fixing the build configuration
#sed -i '$ s/}/,\n"build": {\n  "appId": "ru.yandex.desktop.music",\n  "files": [\n    "build\/**\/*",\n    "main\/**\/*",\n    "node_modules\/**\/*",\n    "package.json"\n  ]\n}\n}/' package.json
sed -i '$ s/}/,\n"build": {\n  "appId": "ru.yandex.desktop.music",\n  "files": [\n    "build\/**\/*",\n    "main\/**\/*",\n    "node_modules\/**\/*",\n    "package.json"\n  ],\n  "directories": {"buildResources":"assets"},\n  "linux": {"icon":"icon.png", "category": "Audio"}\n}\n}/' package.json
echo "Files are patched!"

echo "Extracting icon"
mkdir assets
wrestool -x -t 14 ../*.exe > ../icons.ico
convert "../icons.ico" -thumbnail 256x256 -alpha on -background none -flatten "assets/icon.png"

# fetch dependencies
echo "Fetching dependencies"
npm i 1> /dev/null

# rebuild it
# cd ym
echo "Rebuilding"
npx --yes electron-builder
echo "Built!"

echo "Cleaning up..."
find dist -type f -o -type d \( -name "*linux-unpacked*" -o -name "*.AppImage" -o -name "*.snap" \) -exec cp -r {} ../../ \;
cd ../../
rm -rf music_tmp
