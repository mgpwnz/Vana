#!/bin/bash
VERSION="1.0.7"
# Виведення версії при запуску
echo "Script version: $VERSION"
# Функція для перевірки на порожні значення
function check_empty {
  local varname=$1
  while [ -z "${!varname}" ]; do
    read -p "$2" input
    if [ -n "$input" ]; then
      eval $varname=\"$input\"
    else
      echo "The value cannot be empty. Please try again."
    fi
  done
}

# Функція для підтвердження введених даних
function confirm_input {
  echo "You have entered the following information:"
  for var in "$@"; do
    echo "$var: ${!var}"
  done
  
  read -p "Is this information correct? (yes/no): " CONFIRM
  CONFIRM=$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')
  
  if [ "$CONFIRM" != "yes" ] && [ "$CONFIRM" != "y" ]; then
    echo "Let's try again..."
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
        # Pre Install
        sudo apt update && sudo apt upgrade -y
        sudo apt-get install git -y
        git --version || { echo "git installation failed"; exit 1; }

        # Python
        sudo apt install software-properties-common -y
        sudo add-apt-repository ppa:deadsnakes/ppa -y
        sudo apt update
        sudo apt install python3.11 -y
        python3.11 --version || { echo "Python installation failed"; exit 1; }

        # Poetry
        sudo apt install python3-pip python3-venv curl -y
        curl -sSL https://install.python-poetry.org | python3 -
        export PATH="$HOME/.local/bin:$PATH"
        source ~/.bashrc
        poetry --version || { echo "Poetry installation failed"; exit 1; }

        # Install Node.js using nvm
        if ! command -v nvm &> /dev/null; then
            echo "Installing nvm..."
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
            export NVM_DIR="$HOME/.nvm"
            [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
        fi

        # Install the latest version of Node.js
        nvm install node
        nvm use node

        # Verify installation
        node -v || { echo "Node.js installation failed"; exit 1; }
        npm -v || { echo "npm installation failed"; exit 1; }

        # Install npm via apt (optional)
        sudo apt install npm -y

        # Install yarn globally
        npm install -g yarn
        yarn --version || { echo "Yarn installation failed"; exit 1; }

        echo "DONE"
        break
        ;;

      "Install Node")
        export PATH="$HOME/.local/bin:$PATH"

        cd $HOME
        # Clone repository
        git clone https://github.com/vana-com/vana-dlp-chatgpt.git
        cd vana-dlp-chatgpt
        cp .env.example .env

        # Перевірка, чи встановлено poetry
        if ! command -v poetry &> /dev/null; then
            echo "Poetry is not installed. Installing now..."
            curl -sSL https://install.python-poetry.org | python3 -
            export PATH="$HOME/.local/bin:$PATH" # Додайте ще раз, щоб оновити PATH
            source ~/.bashrc
        fi

        # Встановлення залежностей
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

        break
        ;;

      "Deploy")
        cd $HOME
        # Додайте це на початку скрипта
        export PATH="$HOME/.local/bin:$PATH"

        cd $HOME
        # Клонування репозиторію
        git clone https://github.com/vana-com/vana-dlp-smart-contracts.git
        cd vana-dlp-smart-contracts

        # Перевірка, чи встановлено yarn
        if ! command -v yarn &> /dev/null; then
            echo "Yarn is not installed. Installing now..."
            npm install -g yarn
        fi

        # Встановлення залежностей через Yarn
        yarn install

        # Копіювання файлу .env.example до .env
        cp .env.example .env

        # Цикл для збору та підтвердження інформації
        while true; do
        DPK="" OA="" DN="" DTM="" DTS=""
        check_empty DPK "DEPLOYER_PRIVATE_KEY: "
        check_empty OA "OWNER_ADDRESS: "
        check_empty DN "DLP_NAME: "
        check_empty DTM "DLP_TOKEN_NAME: "
        check_empty DTS "DLP_TOKEN_SYMBOL: "
        confirm_input DPK OA DN DTM DTS
        if [ $? -eq 0 ]; then break; fi
        done

        # Оновлення файлу .env з введеними даними
        sed -i "s/0x71000000000000000000000etc/$DPK/" .env
        sed -i "s/0x00etc/$OA/" .env
        sed -i "s/Custom Data Liquidity Pool/$DN/" .env
        sed -i "s/Custom Data Autonomy Token/$DTM/" .env
        sed -i "s/CUSTOMDAT/$DTS/" .env

        # Деплой на мережу satori
        npx hardhat deploy --network satori --tags DLPDeploy
        cd $HOME

        break
        ;;

      "Pre Validator")
        cd $HOME/vana-dlp-chatgpt
        # Цикл для збору та підтвердження інформації
        while true; do
          OAK="" DLP="" DLPT=""
          check_empty OAK "OPENAI_API_KEY: "
          check_empty DLP "DLP_SATORI_CONTRACT: "
          check_empty DLPT "DLP_TOKEN_SATORI_CONTRACT: "
          confirm_input OAK DLP DLPT
          if [ $? -eq 0 ]; then break; fi
        done

        # Зчитування публічного ключа з файлу
        KEY=$(cat $HOME/vana-dlp-chatgpt/public_key_base64.asc)

        # Створення файлу .env з введеними значеннями
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
        cd $HOME
        continue
        ;;

      "Stake Validator")
        cd $HOME/vana-dlp-chatgpt
        # Реєстрація валідатора з зазначеною ставкою
        ./vanacli dlp register_validator --stake_amount 10
        sleep 5
        
        # Виведення Hotkey адреси валідатора
        echo "Hotkey ADDRESS: $HOT"
        
        # Підтвердження валідатора за допомогою Hotkey адреси
        ./vanacli dlp approve_validator --validator_address=$HOT
        sleep 5
        
        # Виведення шляху до виконуваного файлу poetry
        echo $(which poetry)

        # Створення сервісу для Vana Validator
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

        # Перезавантаження systemd для відображення нового сервісу
        sudo systemctl daemon-reload
        # Додавання сервісу до автозапуску
        sudo systemctl enable vana.service
        # Запуск сервісу
        sudo systemctl start vana.service
        # Перевірка статусу сервісу
        sudo systemctl status vana.service
        continue
        ;;

      "Logs")
        sudo journalctl -u vana.service -f
        continue
        ;;

      "Uninstall")
        # Перевірка наявності директорії vana-dlp-chatgpt
        if [ ! -d "$HOME/vana-dlp-chatgpt" ]; then
          echo "Directory $HOME/vana-dlp-chatgpt does not exist."
          continue
        fi

        # Запит на підтвердження видалення
        read -r -p "Uninstall ? [y/N] " response
        case "$response" in
          [yY][eE][sS]|[yY]) 
            # Видалення директорій та файлів
            rm -rf $HOME/vana-dlp-chatgpt
            rm -rf $HOME/vana-dlp-smart-contracts

            # Зупинка та видалення системного сервісу vana
            sudo systemctl stop vana.service
            sudo systemctl disable vana.service
            sudo systemctl daemon-reload
            sudo rm /etc/systemd/system/vana.service

            echo "Uninstallation completed."
            ;;
          *)
            echo "Canceled"
            ;;
        esac
        continue
        ;;

      "Exit")
        exit
        ;;
      *) echo "Invalid option $REPLY";;
    esac
  done
done
