#!/usr/bin/env bash

### Bash Environment Setup
# http://redsymbol.net/articles/unofficial-bash-strict-mode/
# https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html
# set -o xtrace
set -o errexit
set -o errtrace
set -o nounset
set -o pipefail
IFS=$'\n'

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && cd .. && pwd )"
VERSION_FILE="$DIR/archivebox/VERSION"

function bump_semver {
    echo "$1" | awk -F. '{$NF = $NF + 1;} 1' | sed 's/ /./g'
}

source "$DIR/.venv/bin/activate"
cd "$DIR"

OLD_VERSION="$(cat "$VERSION_FILE")"
NEW_VERSION="$(bump_semver "$OLD_VERSION")"

echo "[*] Fetching latest docs version"
cd "$DIR/docs"
git pull
cd "$DIR"

echo "[+] Building docs"
sphinx-apidoc -o docs archivebox
cd "$DIR/docs"
make html
cd "$DIR"

# if [ -z "$(git status --porcelain)" ] && [[ "$(git branch --show-current)" == "master" ]]; then 
#     git pull
# else
#     echo "[X] Commit your changes and make sure git is checked out on clean master."
#     exit 4
# fi

echo "[*] Bumping VERSION from $OLD_VERSION to $NEW_VERSION"
echo "$NEW_VERSION" > "$VERSION_FILE"
git add "$NEW_VERSION"
git commit -m "$NEW_VERSION release"
git tag -a "$NEW_VERSION"
git push origin master
git push origin --tags

echo "[*] Cleaning up build dirs"
cd "$DIR"
rm -Rf build dist

echo "[+] Building sdist and bdist_wheel"
python3 setup.py sdist bdist_wheel

echo "[^] Uploading to test.pypi.org"
python3 -m twine upload --repository testpypi dist/*

echo "[^] Uploading to pypi.org"
python3 -m twine upload --repository pypi dist/*

echo "[+] Building docker image"
docker build . -t "archivebox,archivebox:latest,archivebox:$NEW_VERSION,nikisweeting/archivebox,docker.pkg.github.com/pirate/ArchiveBox/archivebox:$NEW_VERSION"

echo "[^] Uploading docker image"
# docker login --username=nikisweeting
# docker login docker.pkg.github.com --username=pirate
docker push nikisweeting/archivebox
docker push docker.pkg.github.com/pirate/ArchiveBox/archivebox:$NEW_VERSION

echo "[√] Done. Published version v$NEW_VERSION"
