#!/bin/bash
#
# Script name: build-packages.sh
# Description: Script for automating 'makepkg' on the PKGBUILDS.
# GitLab: https://www.gitlab.com/dwt1/dtos-pkgbuild
# Contributors: Derek Taylor

# Set with the flags "-e", "-u","-o pipefail" cause the script to fail
# if certain things happen, which is a good thing.  Otherwise, we can
# get hidden bugs that are hard to discover.
set -euo pipefail
echo "$0"


REPO_NAME="arch-repo"
REPO_URL="https://github.com/FelixFeuerigel/arch-repo.git"

CHROOT="$PWD/root"

echo "Enter a commit mesage: "
read COMMIT_MESSAGE


if [ -d "../$REPO_NAME" ]; then
    cd ..
    echo "###########################"
    echo "Cloaning the repo database."
    echo "###########################"
    git clone $REPO_URL
    cd -
fi


## make chroot evironment if needed
mkdir -p "$CHROOT"
[[ -d "$CHROOT/root" ]] || mkarchroot -C /etc/pacman.conf "$CHROOT/root" base base-devel

## build packages in "x86_64" directory
readarray -t x86_list <<< "$(find x86_64/ -type f -name PKGBUILD | awk -F / '{print $2}')"
echo "######################"
echo "Building ${#array[@]} packages."
echo "######################"
for x in "${x86_list[@]}"; do
    cd x86_64/"${x}"
    echo "### Making Package: ${x} ###"
    updpkgsums PKGBUILD || echo "FAILED TO UPDATE CHECKSUMS OF PACKAGE: ${x}"
    makechrootpkg -cur $CHROOT -- -cf || echo "FAILED TO MAKE PACKAGE: ${x}"
    # makepkg -cf --sign || echo "FAILED TO MAKE PACKAGE: ${x}"
    # find . -mindepth 1 -maxdepth 1 -type d -print0 | xargs -r0 rm -R
    cd -
done

x86_pkgbuild=$(find /x86_64 -type f -name "*.pkg.tar.zst*")

for x in ${x86_pkgbuild}; do
    echo "Moving ${x} to $REPO_NAME/x86_64"
    mv "${x}" ../$REPO_NAME/x86_64
done

git add .
#git commit -m "$COMMIT_MESSAGE"
#git push

cd ../$REPO_NAME/x86_64

echo "###########################"
echo "Updating the repo database."
echo "###########################"

git pull

echo "###########################"
echo "Building the repo database."
echo "###########################"

rm -f $REPO_NAME*

echo "############################################"
echo "Building database for architecture 'x86_64'."
echo "############################################"

## repo-add
## -s: signs the packages
## -n: only add new packages not already in database
## -R: remove old package files when updating their entry
repo-add -s -n -R $REPO_NAME.db.tar.gz *.pkg.tar.zst

# Removing the symlinks because GitLab can't handle them.
rm $REPO_NAME.db
rm $REPO_NAME.db.sig
rm $REPO_NAME.files
rm $REPO_NAME.files.sig

# Renaming the tar.gz files without the extension.
mv $REPO_NAME.db.tar.gz $REPO_NAME.db
mv $REPO_NAME.db.tar.gz.sig $REPO_NAME-db.sig
mv $REPO_NAME.files.tar.gz $REPO_NAME.files
mv $REPO_NAME.files.tar.gz.sig $REPO_NAME.files.sig

echo "################################"
echo "Uploading the database git repo!"
echo "################################"

git add .
#git commit -m "$COMMIT_MESSAGE"
#git push

echo "#######################################"
echo "Packages in the repo have been updated!"
echo "#######################################"
