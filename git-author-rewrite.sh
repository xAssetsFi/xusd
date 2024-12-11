#!/bin/sh

git filter-branch --env-filter '
CORRECT_NAME="0xNitroColdBrew"
CORRECT_EMAIL="0xnitrocoldbrew@gmail.com"

# Always change the author and committer, regardless of original values
export GIT_COMMITTER_NAME="$CORRECT_NAME"
export GIT_COMMITTER_EMAIL="$CORRECT_EMAIL"
export GIT_AUTHOR_NAME="$CORRECT_NAME"
export GIT_AUTHOR_EMAIL="$CORRECT_EMAIL"
' --tag-name-filter cat -- --branches --tags