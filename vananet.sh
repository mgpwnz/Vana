#!/bin/bash
VERSION="1.2"
# Виведення версії при запуску
echo -e "\e[1;32mScript version: $VERSION\e[0m"  # Зелений текст
# Функція для перевірки на порожні значення
function check_empty {
  local varname=$1
  while [ -z "${!varname}" ]; do
    read -p "$2" input
    if [ -n "$input" ]; then
      eval $varname=\"$input\"
    else
      echo -e "\e[1;31mThe value cannot be empty. Please try again.\e[0m"  # Червоний текст
    fi
  done
}

# Функція для підтвердження введених даних
function confirm_input {
  echo -e "\e[1;34mYou have entered the following information:\e[0m"  # Синій текст
  for var in "$@"; do
    echo -e "\e[1;33m$var:\e[0m ${!var}"  # Жовтий текст
  done
  
  read -p "Is this information correct? (yes/no): " CONFIRM
  CONFIRM=$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')
  
  if [ "$CONFIRM" != "yes" ] && [ "$CONFIRM" != "y" ]; then
    echo -e "\e[1;31mLet's try again...\e[0m"  # Червоний текст
    return 1 
  fi
  return 0 
}

while true; do
  # Menu
  PS3='Select an action: '
  options=("Pre Install" "Install Node" "RUN non-Validator" "Generate validator keys" "RUN Validator" "Submit Deposits" "Validator Logs" "Uninstall" "Exit")
  select opt in "${options[@]}"; do
    case $opt in
      "Pre Install")
                echo -e "\e[1;34mStarting Pre Install...\e[0m"  # Синій текст

        #docker + compose
          touch $HOME/.bash_profile
            cd $HOME
            if ! docker --version; then
              sudo apt update
              sudo apt upgrade -y
              sudo apt install curl jq apt-transport-https ca-certificates gnupg lsb-release -y
              . /etc/*-release
              wget -qO- "https://download.docker.com/linux/${DISTRIB_ID,,}/gpg" | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
              echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/${DISTRIB_ID,,} ${DISTRIB_CODENAME} stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
              sudo apt update
              sudo apt install docker-ce docker-ce-cli containerd.io -y
              docker_version=`apt-cache madison docker-ce | grep -oPm1 "(?<=docker-ce \| )([^_]+)(?= \| https)"`
              sudo apt install docker-ce="$docker_version" docker-ce-cli="$docker_version" containerd.io -y
            fi
            if ! docker compose version; then
              sudo apt update
              sudo apt upgrade -y
              sudo apt install wget jq -y
              local docker_compose_version=`wget -qO- https://api.github.com/repos/docker/compose/releases/latest | jq -r ".tag_name"`
              sudo wget -O /usr/bin/docker-compose "https://github.com/docker/compose/releases/download/${docker_compose_version}/docker-compose-`uname -s`-`uname -m`"
              sudo chmod +x /usr/bin/docker-compose
              . $HOME/.bash_profile
            fi

        break
        ;;
        
      "Install Node")
        echo -e "\e[1;34mStarting Node Installation...\e[0m"  # Синій текст
        cd $HOME
        git clone https://github.com/vana-com/vana.git
        cd $HOME/vana
        cp .env.example .env
        while true; do
          WA="" PK=""
          check_empty WA "WITHDRAWAL_ADDRESS: "
          check_empty PK "DEPOSIT_PRIVATE_KEY: "
          confirm_input WA PK
          if [ $? -eq 0 ]; then break; fi
        done
        sed -i "s/0x0000000000000000000000000000000000000000/$WA/" .env
        sed -i "s/0000000000000000000000000000000000000000000000000000000000000000/$PK/" .env
        cd $HOME
        echo -e "\e[1;32mNode Installation completed.\e[0m"
        break
        ;;
      "RUN non-Validator")
        cd $HOME/vana
        sed -i "s/GETH_SYNCMODE=full/GETH_SYNCMODE=snap/" .env
        cd $HOME
        echo -e "\e[1;34mStarting Validator...\e[0m"  # Синій текст
        docker compose -f $HOME/vana/docker-compose.yml --profile init --profile validator up -d
        break
        ;;       
      "Generate Validator keys")
        echo -e "\e[1;34mStarting Generate validator keys...\e[0m"  # Синій текст
        cd $HOME/vana
        sed -i "s/USE_VALIDATOR=false/USE_VALIDATOR=true/" .env
        docker compose --profile init --profile manual run --rm validator-keygen
        cd $HOME
        break
        ;;
      "RUN Validator")
        echo -e "\e[1;34mStarting Validator...\e[0m"  # Синій текст
        docker compose -f $HOME/vana/docker-compose.yml --profile init --profile validator up -d
        break
        ;;
      "Submit Deposits")
        echo -e "\e[1;34mSubmit Deposits...\e[0m"  # Синій текст
        cd $HOME/vana
        docker compose --profile init --profile manual run --rm submit-deposits
        cd $HOME
        break
        break
        ;;      
      "Validator Logs")
        echo -e "\e[1;34mDisplaying Logs...\e[0m"  # Синій текст
        docker compose -f $HOME/vana/docker-compose.yml --profile=init --profile=node logs -f validator
        break
        ;;
      "Uninstall")
        echo -e "\e[1;34mUninstallation process started...\e[0m"  # Синій текст
        if [ ! -d "$HOME/vana" ]; then
          echo -e "\e[1;31mDirectory $HOME/vana does not exist.\e[0m"
          continue
        fi

        read -r -p "Uninstall ? [y/N] " response
        case "$response" in
          [yY][eE][sS]|[yY]) 
            docker compose -f $HOME/vana/docker-compose.yml --profile init --profile validator down -v
            rm -rf $HOME/vana
            echo -e "\e[1;32mUninstallation completed.\e[0m"
            ;;
          *)
            echo -e "\e[1;31mUninstallation canceled.\e[0m"
            ;;
        esac
        break
        ;;

      "Exit")
        echo -e "\e[1;34mExiting...\e[0m"  # Синій текст
        exit
        ;;
      *) echo -e "\e[1;31mInvalid option $REPLY\e[0m";;
    esac
  done
done
