#         _,met$$$$$gg.          
#      ,g$$$$$$$$$$$$$$$P.       
#    ,g$$P""       """Y$$.".     
#   ,$$P'              `$$$.     
# ',$$P       ,ggs.     `$$b:    
# `d$$'     ,$P"'   .    $$$     
#  $$P      d$'     ,    $$P     
#  $$:      $$.   -    ,d$$'     
#  $$;      Y$b._   _,d$P'       
#  Y$$.    `.`"Y$$$$P"'          
#  `$$b      "-.__               
#   `Y$$b                        
#    `Y$$.                       
#      `$$b.                     
#        `Y$$b.                  
#          `"Y$b._               
#              `""""             
# A daily build of Debian testing release is used as base
#   Tools are usually far outdated on the stable branch, using Debian testing release is also less
#   likely to compare small bugs compared to the unstable releases (which is basically a rolling
#   release like the popular Arch distro)
# Base image ever not being available because it is deleted from docker.io should not occur
#   At the time of writing 'testing images' date back to testing-20170606 (8 years ago) so it is
#   unlikely that there will ever come a point where the image is unavailable while in use, or at
#   least I sincierely hope that someone will update this to the latest build somewhere in the next
#   8 years.
FROM docker.io/debian:testing-20250929

# The dat dir contains all scripts, config files, etc. to set up the image, it is removed afterwards
ARG DAT_DIR=/tmp/dat
COPY dat/ $DAT_DIR

# The username is passed from the devcontainer.json, rather than using a generic user to provide a
#  ____                                 _ _              _   _____                      _                     
# |  _ \ ___ _ __ ___  ___  _ __   __ _| (_)___  ___  __| | | ____|_  ___ __   ___ _ __(_) ___ _ __   ___ ___ 
# | |_) / _ \ '__/ __|/ _ \| '_ \ / _` | | / __|/ _ \/ _` | |  _| \ \/ / '_ \ / _ \ '__| |/ _ \ '_ \ / __/ _ \
# |  __/  __/ |  \__ \ (_) | | | | (_| | | \__ \  __/ (_| | | |___ >  <| |_) |  __/ |  | |  __/ | | | (_|  __/
# |_|   \___|_|  |___/\___/|_| |_|\__,_|_|_|___/\___|\__,_| |_____/_/\_\ .__/ \___|_|  |_|\___|_| |_|\___\___|
#                                                                      |_|                                       
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
    --apt-package buildah \
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
    --install helmfile=v1.1.0 

# Clean up previously copied folder... because making the image a few kb smaller really matters.
# Other than it also being propper convention to afterwards, clean up our
#   __
# <(o )___
#  ( ._> /
#   `---'   sh*t
RUN rm -r $DAT_DIR

# Set the default user to the one created in setup.sh
USER $USERNAME
