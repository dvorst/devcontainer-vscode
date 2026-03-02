#!/bin/bash

# Install python packages
uv sync

# Install pre-commit
sudo pre-commit install

# make symbolic reference of .aws folder in user-dir to root dir
# This makes the aws login of the user work with sudo commands, or commands run as root user
sudo ln --force --symbolic --no-dereference "/home/$USER/.aws /root/.aws"
