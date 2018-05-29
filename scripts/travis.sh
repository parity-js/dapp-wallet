#!/bin/bash

set -e

echo "Running code checks & build"

npm run lint
npm run test
npm run build

# Pull requests and commits to other branches shouldn't try to deploy, just build to verify
if [ "$TRAVIS_PULL_REQUEST" != "false" -o "$TRAVIS_BRANCH" != "master" ]; then
  echo "Branch check completed"

  exit 0
fi

echo "Setting up GitHub config"

git config push.default simple
git config merge.ours.driver true
git config user.name "Travis CI"
git config user.email "$COMMIT_AUTHOR_EMAIL"
git remote set-url origin https://${GH_TOKEN}@github.com/${TRAVIS_REPO_SLUG}.git > /dev/null 2>&1
git add .

echo "Bumping package version"

npm --no-git-tag-version version
npm version patch -m "[CI Skip] %s"

echo "Pushing updated version to github.com/${TRAVIS_REPO_SLUG}.git"

git push --quiet origin HEAD:refs/heads/$TRAVIS_BRANCH > /dev/null 2>&1

echo "Determining current version"

UTCDATE=`date -u "+%Y%m%d-%H%M%S"`
PACKAGE_VERSION=$(cat package.json \
  | grep version \
  | head -1 \
  | awk -F: '{ print $2 }' \
  | sed 's/[",]//g')
VERSION="${PACKAGE_VERSION} (${UTCDATE})"

echo "Cloning dist repo"
TRAVIS_REPO_SLUG_L=${TRAVIS_REPO_SLUG,,}
DIST_REPO_SLUG=${TRAVIS_REPO_SLUG_L/parity-js/js-dist-paritytech}
git clone https://github.com/${DIST_REPO_SLUG}.git dist
cd dist
git remote set-url origin https://${GH_TOKEN}@github.com/${DIST_REPO_SLUG}.git > /dev/null 2>&1
git checkout $TRAVIS_BRANCH

echo "Copying build output"
rm -rf build static
cp -rf ../.build/* .
cp -f ../icon.png ../package.json .
sed "s/VERSION/$PACKAGE_VERSION/" < ../manifest.json >manifest.json

echo "Adding to git"
echo "$VERSION" >README.md
git add .
git commit -m "$VERSION"
git push --quiet origin HEAD:refs/heads/$TRAVIS_BRANCH > /dev/null 2>&1
cd ..

echo "Release completed"

exit 0
