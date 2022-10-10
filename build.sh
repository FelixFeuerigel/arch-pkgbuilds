#!/bin/bash

# Source #
# GitLab: https://www.gitlab.com/dwt1/dtos-pkgbuild

set -euo pipefail
echo "$0"

DB_NAME="fefe-repo"
REPO_NAME="arch-repo"
REPO_URL="https://github.com/FelixFeuerigel/$REPO_NAME.git"
REPO_DIR="../$REPO_NAME"
CHROOT="$PWD/chroot-root"


PKG_DIR="$(pwd)"


## make chroot evironment if needed
mkdir -p "$CHROOT"
chgrp nobody "$CHROOT"
chmod g+ws "$CHROOT"
setfacl -m u::rwx,g::rwx "$CHROOT"
setfacl -d --set u::rwx,g::rwx,o::- "$CHROOT"
[[ -d "$CHROOT/root" ]] || mkarchroot -C /etc/pacman.conf "$CHROOT/root" base base-devel

## build packages in "x86_64" directory
readarray -t x86_list <<< "$(find x86_64/ -type f -name PKGBUILD | awk -F / '{print $2}')"
echo "#####################"
echo "Building ${#x86_list[@]} packages."
echo "#####################"
for x in "${x86_list[@]}"; do
    cd x86_64/"${x}"
    echo -e "\n ### Making Package: ${x} ###"

    # update checksums if the folder contains source files
    if [ $(find . -mindepth 1  -not -name PKGBUILD -not -name *.install | wc -l) -gt 0 ]; then
        updpkgsums PKGBUILD || ( echo "ERROR: FAILED TO UPDATE CHECKSUMS OF PACKAGE: ${x}" && exit 1 )
    fi

    sudo -u nobody makechrootpkg -cur $CHROOT -- -cf || ( echo "ERROR: FAILED TO MAKE PACKAGE: ${x}" && exit 1 )
    # makepkg -cf || ( echo "ERROR: FAILED TO MAKE PACKAGE: ${x}" && exit 1 )
    # makepkg -cf --sign || echo "FAILED TO MAKE PACKAGE: ${x}"  && exit 1
    # find . -mindepth 1 -maxdepth 1 -type d -print0 | xargs -r0 rm -R
    
    cd $PKG_DIR
done

echo "################################################"
echo "Moving the packages to the \"$REPO_NAME\" repo."
echo "################################################"

[[ -d "$REPO_DIR/x86_64/" ]] || mkdir $REPO_DIR/x86_64/

x86_pkgbuild=$(find x86_64/ -type f -name "*.pkg.tar.zst*")

for x in ${x86_pkgbuild}; do
    echo "Moving ${x} to $REPO_DIR/x86_64/"
    mv "${x}" $REPO_DIR/x86_64/
done

git add .
git commit -m "Actions: update checksums" || echo "no PKGBUILD updates to commit"
git push

cd $REPO_DIR/x86_64

echo "###########################"
echo "Building the repo database."
echo "###########################"

rm -f DB_NAME*

echo "############################################"
echo "Building database for architecture 'x86_64'."
echo "############################################"

## repo-add
## -s: signs the packages
## -n: only add new packages not already in database
## -R: remove old package files when updating their entry
repo-add -s -n -R $DB_NAME.db.tar.gz *.pkg.tar.zst

## Removing the symlinks because GitLab can't handle them.
rm $DB_NAME.db
[[ -d $DB_NAME.db.sig ]] && rm $DB_NAME.db.sig
rm $DB_NAME.files
[[ -d $DB_NAME.files.sig ]] && rm $DB_NAME.files.sig

## Renaming the tar.gz files without the extension.
mv $DB_NAME.db.tar.gz $DB_NAME.db
[[ -d $DB_NAME.db.tar.gz.sig ]] && mv $DB_NAME.db.tar.gz.sig $DB_NAME-db.sig
mv $DB_NAME.files.tar.gz $DB_NAME.files
[[ -d $DB_NAME.files.tar.gz.sig ]] && mv $DB_NAME.files.tar.gz.sig $DB_NAME.files.sig


echo "################################"
echo "Uploading the database git repo!"
echo "################################"

git add .
git commit -m "GitHub Actions"  || echo "no database updates to commit"
git push

echo "#######################################"
echo "Packages in the repo have been updated!"
echo "#######################################"

cd $PKG_DIR
