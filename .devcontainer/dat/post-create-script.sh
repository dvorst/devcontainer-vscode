#!/bin/bash

set -euo pipefail
# e: exit if command fails
# u: reference to an unset variable will fail the script
# o pipefail: fail if pipeline fails

echo "—————————————————————————————————————————————————————————————————————————————————————————————"
echo "——————————————————————————————————— post-create-script.sh ———————————————————————————————————"
set -x # print commands to terminal

# Install python packages
uv sync

# Install pre-commit
sudo pre-commit install

# make symbolic reference of .aws folder in user-dir to root dir
# This makes the aws login of the user work with sudo commands, or commands run as root user
sudo ln --force --symbolic --no-dereference "/home/$USER/.aws /root/.aws"

# Configure git
git config merge.ff false
git config pull.rebase true

set +x
echo "——————————————————————————————————— post-create-script.sh ———————————————————————————————————"
echo "—————————————————————————————————————————————————————————————————————————————————————————————"
