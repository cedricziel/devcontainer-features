#!/usr/bin/env bash

VERSION="${VERSION:-"latest"}"

USERNAME="${USERNAME:-"${_REMOTE_USER:-"automatic"}"}"
UPDATE_RC="${UPDATE_RC:-"true"}"
PYTHON_INSTALL_PATH="${INSTALLPATH:-"/usr/local/python"}"

set -e

# Clean up
rm -rf /var/lib/apt/lists/*

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

# Ensure that login shells get the correct path if the user updated the PATH using ENV.
rm -f /etc/profile.d/00-restore-env.sh
echo "export PATH=${PATH//$(sh -lc 'echo $PATH')/\$PATH}" > /etc/profile.d/00-restore-env.sh
chmod +x /etc/profile.d/00-restore-env.sh

# Determine the appropriate non-root user
if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
    USERNAME=""
    POSSIBLE_USERS=("vscode" "node" "codespace" "$(awk -v val=1000 -F ":" '$3==val{print $1}' /etc/passwd)")
    for CURRENT_USER in "${POSSIBLE_USERS[@]}"; do
        if id -u ${CURRENT_USER} > /dev/null 2>&1; then
            USERNAME=${CURRENT_USER}
            break
        fi
    done
    if [ "${USERNAME}" = "" ]; then
        USERNAME=root
    fi
elif [ "${USERNAME}" = "none" ] || ! id -u ${USERNAME} > /dev/null 2>&1; then
    USERNAME=root
fi

architecture="$(uname -m)"
if [ "${architecture}" != "amd64" ] && [ "${architecture}" != "x86_64" ] && [ "${architecture}" != "arm64" ] && [ "${architecture}" != "aarch64" ]; then
    echo "(!) Architecture $architecture unsupported"
    exit 1
fi

apt_get_update()
{
    if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
        echo "Running apt-get update..."
        apt-get update -y
    fi
}

# Ensure apt is in non-interactive to avoid prompts
export DEBIAN_FRONTEND=noninteractive

# Checks if packages are installed and installs them if not
check_packages() {
    if ! dpkg -s "$@" > /dev/null 2>&1; then
        apt_get_update
        apt-get -y install --no-install-recommends "$@"
    fi
}

install_user_package() {
    PACKAGE="$1"

    if [ "$(id -u)" -eq 0 ] && [ "$USERNAME" != "root" ]; then
        su - "$USERNAME" -c "/usr/local/python/current/bin/python3 -m pip install --user --upgrade --no-cache-dir $PACKAGE"
    else
        /usr/local/python/current/bin/python3 -m pip install --user --upgrade --no-cache-dir "$PACKAGE"
    fi
}

install_system_python() {
    check_packages python3 python3-setuptools python3-doc python3-pip python3-venv python3-dev python3-tk libffi-dev gcc

    CURRENT_PATH="${PYTHON_INSTALL_PATH}/current"
    INSTALL_PATH="/usr"

    local current_bin_path="${CURRENT_PATH}/bin"
    if [ "${OVERRIDE_DEFAULT_VERSION}" = "true" ]; then
        rm -rf "${current_bin_path}"
    fi
    if [ ! -d "${current_bin_path}" ] ; then
        mkdir -p "${current_bin_path}"
        # Add an interpreter symlink but point it to "/usr" since python is at /usr/bin/python, add other alises
        ln -s "${INSTALL_PATH}/bin/python3" "${current_bin_path}/python3"
        ln -s "${INSTALL_PATH}/bin/python3" "${current_bin_path}/python"
        ln -s "${INSTALL_PATH}/bin/pydoc3" "${current_bin_path}/pydoc3"
        ln -s "${INSTALL_PATH}/bin/pydoc3" "${current_bin_path}/pydoc"
        ln -s "${INSTALL_PATH}/bin/python3-config" "${current_bin_path}/python3-config"
        ln -s "${INSTALL_PATH}/bin/python3-config" "${current_bin_path}/python-config"
    fi
}

# Install dependencies
check_packages libpango-1.0-0 libpangoft2-1.0-0

# hack - if no python was installed, install the os-provided.
# would be solved by hard devcontainer dependencies
if ! /usr/local/python/current/bin/python3 --version &> /dev/null ; then
    install_system_python
fi

# Install weasyprint if it's missing
if ! weasyprint --info &> /dev/null ; then
    install_user_package cffi
    install_user_package brotli
    install_user_package weasyprint
fi

# Clean up
rm -rf /var/lib/apt/lists/*

echo "Done!"
