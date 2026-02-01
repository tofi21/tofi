#!/bin/bash

# explicit_sync.sh
# Usage: ./scripts/explicit_sync.sh "Commit message"
# This script commits changes in submodules and then updates the parent repo.

MESSAGE="$1"

if [ -z "$MESSAGE" ]; then
  echo "Error: Please provide a commit message."
  echo "Usage: ./scripts/explicit_sync.sh \"Your commit message\""
  exit 1
fi

echo ">> Checking tofi-core..."
cd tofi-core
if [[ -n $(git status -s) ]]; then
    echo "   Committing changes in tofi-core..."
    git add .
    git commit -m "$MESSAGE"
    git push origin master
else
    echo "   No changes in tofi-core."
fi
cd ..

echo ">> Checking tofi-ui..."
cd tofi-ui
if [[ -n $(git status -s) ]]; then
    echo "   Committing changes in tofi-ui..."
    git add .
    git commit -m "$MESSAGE"
    git push origin master
else
    echo "   No changes in tofi-ui."
fi
cd ..

echo ">> Updating Parent Repo..."
# Add the submodule folders (updates the commit pointer)
git add tofi-core tofi-ui
if [[ -n $(git status -s) ]]; then
    git commit -m "chore(submodules): update submodule pointers - $MESSAGE"
    echo "   Parent repo updated."
else
    echo "   Parent repo already up to date."
fi

echo ">> Done!"
