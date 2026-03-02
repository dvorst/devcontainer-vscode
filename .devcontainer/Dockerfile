# A daily build of Debian testing release is used as base
#   Tools are usually far outdated on the stable branch, using Debian testing release is also less
#   likely to compare small bugs compared to the unstable releases (which is basically a rolling
#   release like the popular Arch distro)
# Base image ever not being available because it is deleted from docker.io should not occur
#   At the time of writing 'testing images' date back to testing-20170606 (8 years ago) so it is
#   unlikely that there will ever come a point where the image is unavailable while in use, or at
#   least I sincierely hope that someone will update this to the latest build somewhere in the next
#   8 years.
FROM docker.io/debian:testing-20260223

# The dat dir contains all scripts, config files, etc. to set up the image
# Files that are needed afterwards, should be placed in dat/tmp/ as tmp/ is cleared by the setup
# script
COPY dat/ /

# The username is passed from the devcontainer.json, rather than using a generic user to provide a
# personalised experience
ARG USERNAME

# Root password, is used only in the devcontainer, so having it show up in the logs is fine
ARG ROOT_PASSWORD

# Scripts directory, which will be added to the path for convenience
ARG SCRIPTS_DIR

# Terminal editor to install
ARG TERMINAL_EDITOR

# No cache is used with the RUN commands
#   I don't expect this image will change often, not using RUN cache prevents podman volumes from
#   bloating up / taking up space.
# A single bash script is used instead of seperate RUN commands
#   Debugging Dockerfiles is generally incredibly slow, developping the script from within an
#   empty base container is a far more convenient development experience.
RUN bash $DAT_DIR/setup.sh \
    --create-user $USERNAME \
    --set-root-password $ROOT_PASSWORD \
    --add-to-path "$SCRIPTS_DIR" \
    --apt-package $TERMINAL_EDITOR \
    --apt-package graphviz \
    --apt-package buildah \
    --apt-package shfmt \
    --pipx-package git-remote-codecommit \
    --pipx-package pre-commit \
    --pipx-package cfn-lint \
    --install oh-my-bash \
    --bashrc bashrc.d/oh-my-bash \
    --install blesh \
    --bashrc bashrc.d/blesh \
    --install aws-cli \
    --install uv \
    --bashrc bashrc.d/uv \
    --install databricks-cli \
    --install kubectl \
    --install helm \
    --install helmfile=v1.1.0 \
    --apt-package make \
    # to install aws-cdk, npm is needed; to install npm, nvm is needed
    --install nvm v0.40.4 \
    --install nodejs-and-npm-lts \
    --install aws-cdk

# Set the default user to the one created in setup.sh
USER $USERNAME
