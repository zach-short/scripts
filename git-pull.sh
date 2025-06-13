#!/bin/bash
REPOS=(
  ~/Projects/ezhomesteading/backend
  ~/Projects/ezhomesteading/native
  ~/Projects/ezhomesteading/web
)

for repo in "${REPOS[@]}"; do
  echo "Pulling updates in $repo"
  cd "$repo"
  git add .
  git commit -m "merging"
  git stash
  git checkout main
  git config pull.rebase false  
  git checkout short-staging
  git merge origin main
done
