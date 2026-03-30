#!/bin/bash

set -euxo pipefail
# e: exit if command fails
# u: reference to an unset variable will fail the script
# x: each command run is printed to shell
# o pipefail: fail if pipeline fails

# Internal field seperator
IFS=$'\n\t'

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# Argument parsing

ACTIONS=()
echo "# parsing arguments"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --create-user)
            ACTIONS+=("create-user,$2")
            shift 2
        ;;
        --set-root-password)
            ACTIONS+=("set-root-password,$2")
            shift 2
        ;;
        --add-to-path)
            ACTIONS+=("add-to-path,$2")
            shift 2
        ;;
        --bashrc)
            ACTIONS+=("bashrc,$2")
            shift 2
        ;;
        --apt-package)
            ACTIONS+=("apt-package,$2")
            shift 2
        ;;
        --pipx-package)
            ACTIONS+=("pipx-package,$2")
            shift 2
        ;;
        --install)
            ITEM="$2"
            # item may contain version, which can be detected if an equal sign is present
            #   if not present, the latest version is used
            if [[ "$ITEM" == *"="* ]]; then
                NAME="${ITEM%%=*}"
                VERSION="${ITEM#*=}"
            else
                # if no equal sign is present, use the latest as the version
                NAME="$ITEM"
                VERSION="latest"
            fi
            ACTIONS+=("install,$NAME,$VERSION")
            shift 2
        ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
        ;;
    esac
done

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# Functions

ccurl() {
    # Custom curl command
    #   fail: By default, curl does not consider HTTP response codes to indicate failure. In normal
    #       cases when an HTTP server fails to deliver a document, it returns a body of text and 4xx
    #       HTTP response code. This command causes curl to output an error instead.
    #   location: If the server reports that the requested page has moved to a different location, this
    #       option makes curl redo the request to the new place without throwing an error
    curl --fail --location "$@"
}

pam_fix() {
    echo "# pam_fix()"
    # TODO: find and solve the actual issue rather than hotfixing it
    cat <<'EOF' >> /etc/bash.bashrc

# Manually set USER and HOME env variable
# Normally one should not have to do this, but many distros behave a bit different in Docker.
# One such example is Debian, which configures the PAM (Privileged Access Management) Module to
# reduce the surface of attack, but this inavertly also causes the USER variable to not be set
# when switching users.
export USER=$(id -un)
export HOME=$(getent passwd "$USER" | cut -d: -f6)

EOF
}

add_to_path() {
    echo "# add_to_path()"
    local dir="$1"
    cat <<EOF >> /etc/bash.bashrc

# Dynamically add dir to PATH, if it exists
if [[ -n "$dir" && -d "$dir" ]]; then
  export PATH="\$PATH:$dir"
fi

EOF
}

configure_bashrc() {
    echo "# configure_bashrc()"
    local bashrc=$1
    local current_dir
    
    current_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
    
    # create target dir, --parents prevents it from failing if it already exists
    mkdir --parents "/etc/bashrc.d"
    
    # Copy bashrc.d, a directory with global bash configuration files, to /etc
    #   global: meaning bash configuration for root, all current users and all future users
    cp -r "$current_dir/$bashrc" /etc/bashrc.d/
    
    # ensure that bashrc is loaded
    echo "source /etc/$bashrc" >> /etc/bash.bashrc

    # load bashrc
    source /etc/bash.bashrc
}

install_essential_apt_packages() {
    echo "# install_essential_apt_packages()"
    
    # build-essential & python3-dev: needed if you need to build cpython from source, this might
    #   be the case if you ever install very old packages whose prebuild wheels have been deleted,
    #   but generally these should always be available. If an install prompts an error that build
    #   tools are not available, consider updating Python/Python-packages, rather than installing
    #   these.
    # procps: util to manage/monitor system processes located at /proc
    # curl, wget: utils to download files
    # xz-utils: util to (de)compress files
    # unzip: util to (de)compress files
    # locales: util to set encoding, date/time formatting of terminal
    # sudo: util to elevate privilages of a command runby a user
    # file: util to see encoding and line-terminator style of files
    # dos2unix: util to convert CRLF (Windows) to LF (Unix) line endings
    # git: required by vscode
    # pipx: usefull to install certain tools in a seperate python environment
    # jq: util for selecting keys from jsons in the terminal
    apt-get update
    apt-get upgrade -y
    apt-get install -y procps curl wget xz-utils unzip locales sudo file dos2unix jq git pipx
}

install_apt_package() {
    echo "# install_apt_package()"
    local package=$1
    apt-get install -y $package
}

fix_locale() {
    echo "# fix_locale()"
    # TODO: maybe make it such that the local can be passed as argument to set it?
    # Uncomment en_US.UTF-8 and generate locales
    sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen
    locale-gen
}

install_pipx_packages() {
    echo "# install_pipx_packages()"
    local packages=$1
    pipx install --global "$1"
}

install_oh_my_bash() {
    echo "# install_oh_my_bash()"
    local version=$1
    
    if [[ "$version" != "latest" ]]; then
        echo "NotImplementedError: only installing latest version is supported"  >&2
        exit 1
    fi
    
    # Globally install oh-mybash, which beautifies bash terminal
    # THIS COULD BE BROKEN IN THE FUTURE: since oh-my-bash annoyingly does not have releases, and no
    #   tags, so the latest version 'must' be installed. This is acceptable, since this is a
    #   devcontainer which does not run in production.
    #   https://github.com/ohmybash/oh-my-bash/?tab=readme-ov-file#basic-installation
    url=https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh
    bash -c "$(ccurl $url)" --prefix=/usr/local
}

install_blesh() {
    echo "# install_blesh()"
    local version=$1
    
    if [[ "$version" != "latest" ]]; then
        echo "NotImplementedError: only installing latest version is supported"  >&2
        exit 1
    fi
    
    # Globally install Ble.sh, provides autocompletion in bash, multiline editing and more
    # THIS COULD BE BROKEN IN THE FUTURE: although ble.sh has releases on git, the current release is
    #   2 years old and contains bugs, so the nightly build is used, which contains the latest changes
    #   of the master branch. If they ever change the manner of installation, or if the dependencies
    #   change, it will break this script. This is acceptable, since this is a devcontainer which does
    #   not run in production.
    #   https://github.com/akinomyoga/ble.sh
    url=https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz
    wget --output-document /tmp/blesh.tar.xz $url
    # striping the top-level directory and then adding it, effectively renames it. The top-level dir
    #   by default namely contains the release-version, renaming it basically removes the scripts
    #   dependency on release-name.
    tar --extract --xz --file /tmp/blesh.tar.xz --directory /tmp --strip-components=1 --one-top-level=blesh --verbose
    rm /tmp/blesh.tar.xz
    bash /tmp/blesh/ble.sh --install /usr/local/share
    rm -r /tmp/blesh
}

install_aws_cli() {
    echo "# install_aws_cli()"
    local version=$1
    
    if [[ "$version" != "latest" ]]; then
        echo "NotImplementedError: only installing latest version is supported"  >&2
        exit 1
    fi
    
    # Install AWS Cli
    ccurl --output "/tmp/awscliv2.zip" "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
    unzip /tmp/awscliv2.zip -d /tmp
    /tmp/aws/install
    rm -r /tmp/aws /tmp/awscliv2.zip
}

install_uv() {
    echo "# install_uv()"
    local version=$1
    
    if [[ "$version" != "latest" ]]; then
        echo "NotImplementedError: only installing latest version is supported"  >&2
        exit 1
    fi
    
    # Globally install uv, a python package manager
    #   https://docs.astral.sh/uv/reference/installer/#changing-the-installation-path
    curl --fail -LsS https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="/usr/local/bin" sh
}

install_databricks_cli() {
    echo "# install_databricks_cli()"
    local version=$1
    
    if [[ "$version" != "latest" ]]; then
        echo "NotImplementedError: only installing latest version is supported"  >&2
        exit 1
    fi
    
    # Install Databricks CLI, installs to /usr/local/bin/databricks by default
    curl -fsSL https://raw.githubusercontent.com/databricks/setup-cli/main/install.sh | sh
}

install_kubectl() {
    echo "# install_kubectl()"
    local version=$1
    
    if [[ "$version" != "latest" ]]; then
        echo "NotImplementedError: only installing latest version is supported"  >&2
        exit 1
    fi
    
    # Install kubectl
    # TODO: remove this once airbyte has been set up properly with application load balancer
    latest_release=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    curl --location --output "/tmp/kubectl" "https://dl.k8s.io/release/${latest_release}/bin/linux/amd64/kubectl"
    install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl
    rm /tmp/kubectl
}

install_helm() {
    echo "# install_helm()"
    local version=$1
    
    if [[ "$version" != "latest" ]]; then
        echo "NotImplementedError: only installing latest version is supported"  >&2
        exit 1
    fi
    
    # configure env vars
    cat <<'EOF' >> /etc/bash.bashrc
# Configure HELM as a global install
export HELM_CACHE_HOME=/var/cache/helm
export HELM_CONFIG_HOME=/etc/helm
export HELM_DATA_HOME=/usr/local/share/helm

EOF
    source /etc/bash.bashrc
    
    # Install helm
    curl --location --output /tmp/helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod +x /tmp/helm.sh
    /tmp/helm.sh
    rm /tmp/helm.sh
    
    # Make the config and cache dir, and allow any user to modify them
    mkdir /etc/helm
    chmod 777 /etc/helm
    mkdir /var/cache/helm
    chmod -R 777 /var/cache/helm
}


install_helmfile() {
    echo "# install_helmfile()"
    local version=$1
    local url
    echo "## version: $1"

    # TODO: why does the source bashrc in install_helm not work?
    export HELM_CACHE_HOME=/var/cache/helm
    export HELM_CONFIG_HOME=/etc/helm
    export HELM_DATA_HOME=/usr/local/share/helm
    
    # Install plugins required by helmfile
    helm plugin install https://github.com/databus23/helm-diff
    helm plugin install https://github.com/aslafy-z/helm-git
    
    
    # Url to query for the release file
    if [[ "$version" == "latest" ]]; then
        url="https://api.github.com/repos/helmfile/helmfile/releases/latest"
    else
        url="https://api.github.com/repos/helmfile/helmfile/releases/tags/$version"
    fi
    
    # Get asset for the specified release, that is meant for linux, amd64 architecture
    download_url=$(curl -s "$url" | jq -r '
      .assets[] |
      select(.name | test("linux.*amd64|amd64.*linux"; "i")) |
      .browser_download_url
    ')
    
    # Download helmfile and install
    ccurl --output /tmp/helmfile.tar.gz $download_url
    mkdir /tmp/helmfile
    tar --extract --gzip --file /tmp/helmfile.tar.gz --directory /tmp/helmfile
    mv /tmp/helmfile/helmfile /usr/local/bin
    rm -r /tmp/helmfile.tar.gz /tmp/helmfile
}

create_user() {
    echo "# create_user()"
    local username=$1
    
    # Create user with no ROOT_PASSWORD
    # Some tools will complain when run as root, hence, a normal user account is created.
    # The default UID_MIN and GID_MIN are 100000, and default counts are 65536.
    # If the devcontainer is run rootless, with a user that has these defaults, then creating a
    # user inside this container with the same defaults will not be possible. useradd will not give
    # an error when creating the user, but an error will be generated when building containers.
    # By default, the linux namespace will be mapped as follows:
    #   - root (0) in container maps to the user (such as 1000) on host
    #   - ids 1:65536 in container will be mapped to 524288:589824 on host
    # Note that 65536 = 2^16
    # By using subid 10000 count 32768 (2^15), the max id will be 42768, which is within the
    # range 1:65536 that is mapped.
    useradd \
        --create-home \
        --shell /bin/bash \
        --user-group $username #\
        # --key SUB_UID_MIN=10000 \
        # --key SUB_UID_COUNT=32768 \
        # --key SUB_GID_MIN=10000 \
        # --key SUB_GID_COUNT=32768 \

    echo "${username}::" | chpasswd
    
    # Allow user to run sudo without having to provide ROOT_PASSWORD
    echo "$username ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/$username
    sudo chmod 440 /etc/sudoers.d/$username
    
    # login as the user without doing anything, to update some cache that oh-my-bash/ble.sh uses
    runuser --login --session-command '' $username
}

set_root_password() {
    echo "# set_root_password()"
    local root_password=$1
    
    # Change root password
    echo "root:${root_password}" | chpasswd
}

install_custom() {
    echo "# install_custom()"
    name=$1
    version=$2

    # construct function handle that is to be called
    func="install_${name//-/_}"

    # raise error if function handle does not exist
    if ! declare -F "$func" > /dev/null; then
        echo "Error: installer not defined for '$name'" >&2
        echo "Available install options are:" >&2
        # List all functions starting with 'install_'
        declare -F | awk '{print $3}' | grep '^install_' | sed 's/install_/_/g;s/_/-/g' >&2
        exit 1
    fi
    
    # Call function handle
    "$func" "$version"
}


cleanup() {
    echo "# cleanup()"
    # remove apt lists to reduce image size
    # A user should run apt update anyway if he/she wants to install something
    rm -rf /var/lib/apt/lists/*
}


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

main() {
    echo "# main()"

    pam_fix
    install_essential_apt_packages
    fix_locale

    for action in "${ACTIONS[@]}"; do
        IFS=',' read -r type param1 param2 <<< "$action"

        case "$type" in
            create-user)
                create_user "$param1"
            ;;
            set-root-password)
                set_root_password "$param1"
            ;;
            add-to-path)
                add_to_path "$param1"
            ;;
            bashrc)
                configure_bashrc "$param1"
            ;;
            apt-package)
                install_apt_package "$param1"
            ;;
            pipx-package)
                install_pipx_packages "$param1"
            ;;
            install)
                install_custom "$param1" "$param2"
            ;;
            *)
                echo "Unknown action type: $type" >&2
                exit 1
            ;;
        esac
    done

    cleanup

}

main "$@"


