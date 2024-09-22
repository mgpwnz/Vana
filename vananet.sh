#!/bin/bash
VERSION="1.1.0"
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
  options=("Pre Install" "Install Node" "Deploy" "Pre Validator" "Stake Validator" "Logs" "Uninstall" "Exit")
  select opt in "${options[@]}"; do
    case $opt in
      "Pre Install")
        echo -e "\e[1;34mStarting Pre Install...\e[0m"  # Синій текст
        sudo apt update && sudo apt upgrade -y
        sudo apt-get install git -y
        git --version || { echo -e "\e[1;31mGit installation failed\e[0m"; exit 1; }

        # Python
        sudo apt install software-properties-common -y
        sudo add-apt-repository ppa:deadsnakes/ppa -y
        sudo apt update
        sudo apt install python3.11 python3-pip python3-venv curl -y
        python3.11 --version || { echo -e "\e[1;31mPython installation failed\e[0m"; exit 1; }

        # Poetry
        if ! command -v poetry &> /dev/null; then
            echo -e "\e[1;32mInstalling Poetry...\e[0m"  # Зелений текст
            sudo apt install python3-poetry -y || {
                echo -e "\e[1;31mPoetry installation via apt failed. Trying curl...\e[0m"
                curl -sSL https://install.python-poetry.org | python3 - || {
                    echo -e "\e[1;31mPoetry installation via curl failed.\e[0m"
                    exit 1
                }
            }
        else
            echo -e "\e[1;32mPoetry is already installed.\e[0m"
        fi

        # Додати Poetry до PATH, якщо ще не додано
        if ! grep -q "$HOME/.local/bin" ~/.bashrc; then
            echo "export PATH=\"$HOME/.local/bin:\$PATH\"" >> ~/.bashrc
            source ~/.bashrc
            hash -r
        fi

        # Перевірка версії Poetry
        poetry --version || { echo -e "\e[1;31mPoetry installation failed\e[0m"; exit 1; }

        # Install Node.js using nvm
        if ! command -v nvm &> /dev/null; then
            echo -e "\e[1;32mInstalling nvm...\e[0m"
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
            source "$HOME/.nvm/nvm.sh"  # Завантажити nvm
        fi

        # Install the latest version of Node.js
        nvm install node
        nvm use node

        # Verify installation
        node -v || { echo -e "\e[1;31mNode.js installation failed\e[0m"; exit 1; }
        npm -v || { echo -e "\e[1;31mnpm installation failed\e[0m"; exit 1; }

        # Install yarn globally
        npm install -g yarn
        yarn --version || { echo -e "\e[1;31mYarn installation failed\e[0m"; exit 1; }

        echo -e "\e[1;32mPre Install completed.\e[0m"
        break
        ;;
        
      "Install Node")
        echo -e "\e[1;34mStarting Node Installation...\e[0m"  # Синій текст
        export PATH="$HOME/.local/bin:$PATH"
        cd $HOME
        # Clone repository
        git clone https://github.com/vana-com/vana-dlp-chatgpt.git
        cd vana-dlp-chatgpt
        cp .env.example .env

        if ! command -v poetry &> /dev/null; then
            echo -e "\e[1;31mPoetry is not installed. Installing now...\e[0m"
            curl -sSL https://install.python-poetry.org | python3 -
            export PATH="$HOME/.local/bin:$PATH"
            source ~/.bashrc
        fi

        poetry install
        pip install vana

        # Генерація гаманця
        vanacli wallet create --wallet.name default --wallet.hotkey default
        sleep 3

        # Експорт ключів
        vanacli wallet export_private_key --wallet.name default
        sleep 4
        vanacli wallet export_private_key --wallet.name default --wallet.hotkey default

        # Генерація ключів
        chmod +x keygen.sh
        ./keygen.sh
        cd $HOME

        echo -e "\e[1;32mNode Installation completed.\e[0m"
        break
        ;;

      "Deploy")
        echo -e "\e[1;34mStarting Deployment...\e[0m"  # Синій текст
        cd $HOME
        export PATH="$HOME/.local/bin:$PATH"
        cd $HOME
        git clone https://github.com/vana-com/vana-dlp-smart-contracts.git
        cd vana-dlp-smart-contracts

        if ! command -v yarn &> /dev/null; then
            echo -e "\e[1;31mYarn is not installed. Installing now...\e[0m"
            npm install -g yarn
        fi

        yarn install
        cp .env.example .env

        while true; do
          DPK="" OA="" DN="" DTN="" DTS=""
          check_empty DPK "Coldkey_PRIVATE_KEY: "
          check_empty OA "Coldkey_ADDRESS: "
          check_empty DN "Data Liquidity Pool NAME: "
          check_empty DTN "Data Liquidity Pool TOKEN NAME: "
          check_empty DTS "Data Liquidity Pool TOKEN SYMBOL: "
          confirm_input DPK OA DN DTN DTS
          if [ $? -eq 0 ]; then break; fi
        done

        sed -i "s/0x71000000000000000000000etc/$DPK/" .env
        sed -i "s/0x00etc/$OA/" .env
        sed -i "s/Custom Data Liquidity Pool/$DN/" .env
        sed -i "s/Custom Data Autonomy Token/$DTN/" .env
        sed -i "s/CUSTOMDAT/$DTS/" .env

        npx hardhat deploy --network satori --tags DLPDeploy
        cd $HOME

        echo -e "\e[1;32mDeployment completed.\e[0m"
        break
        ;;

      "Pre Validator")
        echo -e "\e[1;34mStarting Pre Validator Configuration...\e[0m"  # Синій текст
        cd $HOME/vana-dlp-chatgpt
        while true; do
          OAK="" DLP="" DLPT=""
          check_empty OAK "OPENAI_API_KEY: "
          check_empty DLP "Data Liquidity Pool CONTRACT: "
          check_empty DLPT "Data Liquidity Pool TOKEN CONTRACT: "
          confirm_input OAK DLP DLPT
          if [ $? -eq 0 ]; then break; fi
        done

        KEY=$(cat $HOME/vana-dlp-chatgpt/public_key_base64.asc)

        cat << EOF > $HOME/vana-dlp-chatgpt/.env
# The network to use, currently Vana Satori testnet
OD_CHAIN_NETWORK=satori
OD_CHAIN_NETWORK_ENDPOINT=https://rpc.satori.vana.org

# Optional: OpenAI API key for additional data quality check
OPENAI_API_KEY="$OAK"

# Optional: Your own DLP smart contract address once deployed to the network, useful for local testing
DLP_SATORI_CONTRACT="$DLP"

# Optional: Your own DLP token contract address once deployed to the network, useful for local testing
DLP_TOKEN_SATORI_CONTRACT="$DLPT"

# The private key for the DLP, follow "Generate validator encryption keys" section in the README
PRIVATE_FILE_ENCRYPTION_PUBLIC_KEY_BASE64="$KEY"
EOF

        echo -e "\e[1;32mPre Validator Configuration completed.\e[0m"
        cd $HOME
        break
        ;;

      "Stake Validator")
        echo -e "\e[1;34mStarting Validator Staking...\e[0m"  # Синій текст
        cd $HOME/vana-dlp-chatgpt
        ./vanacli dlp register_validator --stake_amount 10
        sleep 5

        read -p "Hotkey ADDRESS : " HOT
        ./vanacli dlp approve_validator --validator_address=$HOT
        sleep 5

        echo -e "\e[1;32mValidator Staking completed.\e[0m"
        echo $(which poetry)

        sudo tee /etc/systemd/system/vana.service << EOF
[Unit]
Description=Vana Validator Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/vana-dlp-chatgpt
ExecStart=/root/.local/bin/poetry run python -m chatgpt.nodes.validator
Restart=on-failure
RestartSec=10
Environment=PATH=/root/.local/bin:/usr/local/bin:/usr/bin:/bin:/root/vana-dlp-chatgpt/myenv/bin
Environment=PYTHONPATH=/root/vana-dlp-chatgpt

[Install]
WantedBy=multi-user.target
EOF

        sudo systemctl daemon-reload
        sudo systemctl enable vana.service
        sudo systemctl start vana.service
        sudo systemctl status vana.service
        break
        ;;

      "Logs")
        echo -e "\e[1;34mDisplaying Logs...\e[0m"  # Синій текст
        sudo journalctl -u vana.service -f
        break
        ;;

      "Uninstall")
        echo -e "\e[1;34mUninstallation process started...\e[0m"  # Синій текст
        if [ ! -d "$HOME/vana-dlp-chatgpt" ]; then
          echo -e "\e[1;31mDirectory $HOME/vana-dlp-chatgpt does not exist.\e[0m"
          continue
        fi

        read -r -p "Uninstall ? [y/N] " response
        case "$response" in
          [yY][eE][sS]|[yY]) 
            rm -rf $HOME/vana-dlp-chatgpt
            rm -rf $HOME/vana-dlp-smart-contracts

            sudo systemctl stop vana.service
            sudo systemctl disable vana.service
            sudo systemctl daemon-reload
            sudo rm /etc/systemd/system/vana.service

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
