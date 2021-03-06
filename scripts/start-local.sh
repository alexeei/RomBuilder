#!/bin/bash

# Script for local build V1.0

# Get lang of device
lang=$(echo $LANG | awk -F. {'print $1'})

if [[ $lang == "it_IT" ]]; then
  shell_lang="it"
else
  shell_lang="en"
fi

error_exit()
{
    ret="$?"
    if [ "$ret" != "0" ]; then
      if [[ $shell_lang == "it" ]]; then
        echo "Errore - '$1' non riuscito con codice di ritorno '$ret'"
      else
        echo "Error - '$1' failed with return code '$ret'"
      fi
      exit 1
    fi
}

# Install requirements for build
CURRENT="$(pwd)"

# Requirements for buildkite
new=0

if [ -f "/etc/lsb-release" ] && [ ! -d "/opt/build_env" ]; then
  # Linux install

  if [ ! -z "$DOCKER_SETUP" ]; then
    apt-get install -y sudo
  fi

  if [[ $shell_lang == "it" ]]; then
    echo "--- Installazione degli strumenti richiesti :toolbox:"
    echo "Installazione dello script di compilazione"
  else
    echo "--- Installing required tools :toolbox:"
    echo "Installing build script"
  fi

  apt-get install git curl -y > /dev/null 2>&1
  git config --global user.name "Robert Balmbra" > /dev/null 2>&1
  git config --global user.email "robbalmbra@gmail.com" > /dev/null 2>&1
  error_exit "git config"

  git clone https://github.com/akhilnarang/scripts.git /opt/build_env --depth=1 > /dev/null 2>&1
  sudo chmod +x /opt/build_env/setup/android_build_env.sh
  . /opt/build_env/setup/android_build_env.sh > /dev/null 2>&1

  apt-get -y upgrade > /dev/null 2>&1 && \
  apt-get -y install make python3 bc bison git screen wget openjdk-8-jdk lsb-core sudo curl shellcheck \
  autoconf libtool g++ libcrypto++-dev build-essential libz-dev libsqlite3-dev libssl-dev libcurl4-gnutls-dev libreadline-dev \
  libpcre++-dev libsodium-dev libc-ares-dev libfreeimage-dev libavcodec-dev libavutil-dev libavformat-dev flex \
  libswscale-dev libmediainfo-dev libzen-dev libuv1-dev libxkbcommon-dev libxkbcommon-x11-0 zram-config python3-pip \
  libelf-dev libncurses-dev g++-multilib gcc-multilib gperf libxml2 libxml2-utils zlib1g-dev zip yasm jq \
  squashfs-tools xsltproc schedtool rsync lzop liblz4-tool libesd0-dev lib32z1-dev lib32readline-dev libsdl1.2-dev > /dev/null 2>&1

  # Install python packages
  pip3 install python-telegram-bot --upgrade > /dev/null 2>&1

  # Download and build mega
  if [ ! -d "/opt/MEGAcmd/" ]; then
    if [[ $shell_lang == "it" ]]; then
      echo "Installazione di mega CLI"
    else
      echo "Installing mega CLI"
    fi

    wget --quiet -O /opt/megasync.deb https://mega.nz/linux/MEGAsync/xUbuntu_$(lsb_release -rs)/amd64/megasync-xUbuntu_$(lsb_release -rs)_amd64.deb && ls /opt/ && dpkg -i /opt/megasync.deb
    cd /opt/ && git clone --quiet https://github.com/meganz/MEGAcmd.git
    cd /opt/MEGAcmd && git submodule update --quiet --init --recursive && sh autogen.sh > /dev/null 2>&1 && ./configure --quiet && make > /dev/null 2>&1 && make install > /dev/null 2>&1
  fi

  apt update -y --fix-missing > /dev/null 2>&1
  sudo apt install -y -f  > /dev/null 2>&1
  new=1

elif [ "$(uname)" == "Darwin" ]; then
  # MacOS install
  # Check if software exists on system
  if [ ! -f "$HOME/.complete" ]; then

    # Check if brew is installed
    if ! [ -x "$(command -v brew)" ]; then
      if [[ $shell_lang == "it" ]]; then
        echo 'Errore: Brew non è installato'
      else
        echo 'Error - Brew is not installed'
      fi
      exit 1
    fi

    # Install gnu sed for compatibility issues
    if [[ $shell_lang == "it" ]]; then
      echo "--- Installazione degli strumenti richiesti"
      echo "Installazione di strumenti specifici di gnu"
    else
      echo "--- Installing required tools"
      echo "Installing gnu specific tools"
    fi

    brew install gnu-sed > /dev/null 2>&1
    brew install coreutils > /dev/null 2>&1
    brew install ccache > /dev/null 2>&1
    wget https://storage.googleapis.com/git-repo-downloads/repo -O /usr/local/bin/repo > /dev/null 2>&1
    chmod +x /usr/local/bin/repo

    export PATH="/usr/local/opt/python@3.8/bin:$PATH"
    export LDFLAGS="-L/usr/local/opt/python@3.8/lib"
    new=1
    touch $HOME/.complete

  fi
fi

if [[ -z "${BUILDKITE}" ]]; then
  export USE_CCACHE=1
  # Pass other parameter to build through env vars
fi

# Check vars
variables=(
  BUILD_NAME
  UPLOAD_NAME
  MEGA_USERNAME
  MEGA_PASSWORD
  DEVICES
  REPO
  BRANCH
  LOCAL_REPO
  LOCAL_BRANCH
)

# Check if required variables are set
quit=0
for variable in "${variables[@]}"
do
  if [[ -z ${!variable+x} ]]; then
    if [[ $shell_lang == "it" ]]; then
      echo "$0 - Errore, $variable non è impostato.";
    else
      echo "$0 - Error, $variable isn't set.";
    fi
    quit=1
    break
  fi
done

# Quit if env requirements not met
if [ "$quit" -ne 0 ]; then
  exit 1
fi

if [ -z "$TEST_BUILD" ]; then
  if [ -z "$MEGA_FOLDER_ID" ]; then
    echo "$0 - Error, MEGA_FOLDER_ID isn't set."
    exit 1
  fi

  if [ -z "$MEGA_DECRYPT_KEY" ]; then
    echo "$0 - Error, MEGA_DECRYPT_KEY isn't set."
    exit 1
  fi

  TEST_BUILD=0
fi

# Check if telegram vars are all set if any telegram variable are specified
variables=(
  TELEGRAM_TOKEN
  TELEGRAM_GROUP
  TELEGRAM_AUTHORS
)

count=0
for variable in "${variables[@]}"
do
  if [[ ${!variable+x} ]]; then
    ((count=count+1))
  fi
done

if [ $count -gt 0] && [ $count -lt 3 ]; then
  echo "Error - TELEGRAM_TOKEN, TELEGRAM_GROUP and TELEGRAM_AUTHORS are required for TELEGRAM to function."
  exit 1
fi

if [ $new -eq 0 ]; then
  if [[ $shell_lang == "it" ]]; then
    echo "--- Recupero di strumenti e file del supplemento :page_facing_up:"
  else
    echo "--- Retrieving supplement tools and files :page_facing_up:"
  fi
fi

# Check and get user modifications either as a url or env string
cd "$CURRENT"
if [[ ! -z "$USER_MODIFICATIONS" ]]; then
  if [[ $shell_lang == "it" ]]; then
    echo "Recupero modifiche utente"
  else
    echo "Retrieving user modifications"
  fi

  regex='(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'
  if [[ $USER_MODIFICATIONS =~ $regex ]]
  then
    # Get url and save to local file
    if [[ $shell_lang == "it" ]]; then
      echo "Download e salvataggio di $USER_MODIFICATIONS in '$CURRENT/user_modifications.sh'"
    else
      echo "Downloading and saving $USER_MODIFICATIONS to '$CURRENT/user_modifications.sh'"
    fi
    wget $USER_MODIFICATIONS -O "$CURRENT/user_modifications.sh"
  else
    if [[ $shell_lang == "it" ]]; then
      echo "Errore - '$USER_MODIFICATIONS' non è un URL valido."
    else
      echo "Error - '$USER_MODIFICATIONS' isn't a valid url."
    fi
    exit 1
  fi

  chmod +x "$CURRENT/user_modifications.sh"
  chmod +x "$CURRENT/buildkite_logger.sh"
  export USER_MODS="$CURRENT/user_modifications.sh"
fi

# Override if modification file exists from buildkite stage
if [[ ! -z "$USER_MODS" ]]; then
  if [[ ! -f "$USER_MODS" ]]; then
    if [[ $shell_lang == "it" ]]; then
      echo "Errore - '$USER_MODS' non esiste."
    else
      echo "Error - '$USER_MODS' doesnt exist."
    fi
    exit 1
  fi
  if [[ $shell_lang == "it" ]]; then
    echo "Usando '$USER_MODS' come script di modifica"
  else
    echo "Using '$USER_MODS' as modification script"
  fi
  chmod +x $USER_MODS
fi

# Run build
if [[ $shell_lang == "it" ]]; then
  echo "--- Inizializzazione dell'ambiente di compilazione :parcel:"
else
  echo "--- Initializing build environment :parcel:"
fi

# Check os
if [[ "$OSTYPE" == "darwin"* ]]; then
  export MACOS=1
fi

export BUILDKITE_LOGGER="$CURRENT/buildkite_logger.sh"
export ROM_PATCHER="$CURRENT/patcher.sh"
export TELEGRAM_BOT="$CURRENT/SendMessage.py"
export SUPPLEMENTS="$CURRENT/../supplements/"
export BUILD_LANG="$shell_lang"
export PRELIMINARY_SETUP=1

"$(pwd)/../docker/build.sh"
error_exit "build script"
