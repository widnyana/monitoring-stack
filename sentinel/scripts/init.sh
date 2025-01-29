#!/bin/bash
set -euo pipefail

MARKER_FILE="configs/.initialized"

BEKGRON="\e[40m"
BLACK="\e[30m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RESET="\033[0m"

COMMAND=$(cat <<"EOF"
  docker compose \
    -f docker-compose.yaml \
    -f compose.grafana.yaml \
    -f compose.mikrotik.yaml \
    -f compose.postgresql.yaml \
    -f compose.prometheus.yaml
EOF
)


aborted() {
  echo -e "\n${RED} [!] Setup met a tragic end. Its memory address will never be forgotten...${RESET}"
  exit 0
}
trap aborted SIGINT

check_marker() {
  if [ -f "$MARKER_FILE" ]; then
    echo -e "${RED} [!] Configuration has already been initialized. Exiting.${RESET}"
    exit 0
  fi
}

banner() {
  clear
  echo -e "${GREEN}"
  cat << "EOF"
                   _____________________________                         
                  |                             |_____    __             
                  | Monitoring Stack - Setup    |    ~|__|  |__________  
                  | \./ github.com/widnyana     |  ~  |::| *| +   +   /  
                  |_____________________________| ~ ~ |::|* |   +    /   
      /\**/\       |                             \.___|::|__| +   + <    
     ( o_o  )_     |                                  \::/  \.________\  
      (u--u   \_)  |                                                     
      (||___   )==\                                                      
    ,dP"/b/=( /P"/b\                                                     
    |8 || 8\=== || 8                                                     
    `b,  ,P  `b,  ,P                                                     
      """`     """`                                                      
EOF
  echo -e "${RESET}"
}


# Function to check if Docker is installed and if the current user can execute Docker without sudo
check_docker_installation() {
  # Check if Docker is installed
  if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed.${RESET}"
    exit 1
  fi

  # Check if the current user can execute Docker without sudo
  if groups $USER | grep &>/dev/null "\bdocker\b"; then
    echo "Docker is installed and you can run Docker without sudo."
  else
    echo -e "${RED}"
    echo "Docker is installed, but your user is not configured to run docker without sudo."
    echo "use command below, then reinitialize your terminal session to make it effective."
    echo -e "    sudo usermod -aG docker \$(whoami) "
    echo -e "${RESET}"

    exit 1
  fi
}

# This script initializes the PostgreSQL configuration by prompting the user for
# PostgreSQL username, password, and database name, and then saves these values
# into respective configuration files.
initialize_postgresql() {
  echo -e "${GREEN}  ;;----------------------------------------------------------------------------"
  echo -e "${GREEN}  >_ init     !                         Initializing PostgreSQL configuration..."
  echo -e "${RESET}${CYAN}"

  read -p "  [>] Enter PostgreSQL username: " PG_USERNAME
  echo "${PG_USERNAME}" > configs/postgresql/17/.env.pg17-username

  read -sp "  [>] Enter PostgreSQL password: " PG_PASSWORD
  echo "${PG_PASSWORD}" > configs/postgresql/17/.env.pg17-password
  echo

  read -p "  [>] Enter PostgreSQL database name: " PG_DBNAME
  echo "${PG_DBNAME}" > configs/postgresql/17/.env.pg17-database

  echo -e "${RESET}"
  echo -e "${GREEN}  [+] PostgreSQL has been configured!${RESET}"
  
}

configure_grafana() {
  echo -e "${GREEN}  ;;----------------------------------------------------------------------------"
  echo -e "${GREEN}  >_ init     !                                  Configuring Grafana Instance..."
  echo -e "${RESET}${CYAN}"

  read -sp "  [>] Enter PostgreSQL password for Grafana: " GRAFANA_PG_PASSWORD
  echo

  ESCAPED_PASSWORD=$(printf '%s\n' "${GRAFANA_PG_PASSWORD}" | sed 's/[\/&]/\\&/g')
  sed -i "s/{{GRAFANA_DB_PASSWORD}}/${ESCAPED_PASSWORD}/g" \
    configs/postgresql/17/docker-entrypoint-initdb.d/user.grafana.sh \
    configs/grafana/grafana.ini

  __GRAFANA_SECRET_KEY=$(openssl rand -base64 48 | tr -d '/+=' | cut -c1-64)
  sed -i "s/{{GRAFANA_SECRET_KEY}}/$__GRAFANA_SECRET_KEY/g" configs/grafana/grafana.ini

  echo -e "${RESET}"
  echo -e "${GREEN}  [+] Grafana has been configured!${RESET}"
}

# configure mikrotik exporter
configure_mikrotik_exporter() {
  echo -e "${GREEN}  ;;----------------------------------------------------------------------------"
  echo -e "${GREEN}  >_ init     !                                 Configuring Mikrotik Exporter..."
  echo -e "${RESET}${CYAN}"

  read -p "  [>] Enter Your Mikrotik IP Address: " MIKROTIK_IP
  sed -i "s/__MIKROTIK_IP__/$MIKROTIK_IP/g" configs/mktxp/mktxp.conf

  read -p "  [>] Enter Your Mikrotik API Username: " MIKROTIK_API_USERNAME
  sed -i "s/__MIKROTIK_API_USERNAME__/${MIKROTIK_API_USERNAME}/g" configs/mktxp/mktxp.conf

  read -sp "  [>] Enter Your Mikrotik API Password: " MIKROTIK_API_PASSWORD
  echo
  MKTXP_ESCAPED_PASSWORD=$(printf '%s\n' "${MIKROTIK_API_PASSWORD}" | sed 's/[\/&]/\\&/g')
  sed -i "s/__MIKROTIK_API_PASSWORD__/${MKTXP_ESCAPED_PASSWORD}/g" configs/mktxp/mktxp.conf
  echo -e "${RESET}"

  echo -e "${GREEN}  [+] Mikrotik Exporter has been configured!${RESET}"
}


ask_for_npm() {
  echo -e "${GREEN}  ;;----------------------------------------------------------------------------"
  echo -e "${GREEN}  >_ init     !                               Configuring Nginx Proxy Manager..."
  echo -e
  echo -e "  Do you want to use Nginx Proxy Manager? answer with n if you already have a"
  echo -e "  reverse-proxy running or you're brave enough to expose grafana directly.${RESET}"
  echo -e "${CYAN}"
  read -p "  [>] [y/n]: " answer
  echo -e "${RESET}"
  case "$answer" in
    [Yy]* )
      configure_npm
      ;;
    [Nn]* )
      echo -e "${YELLOW}  [!] Not configuring Nginx Proxy Manager.${RESET}\n\n"
      ;;
    * )
      echo -e "${RED}Invalid input. Please answer with y or n.${RESET}\n\n"
      ask_for_npm
      ;;
  esac
}

configure_npm() {
  __NPM_COMPOSE_FILE="compose.reverse-proxy.yaml"

  echo -e "${CYAN}"
  read -p "  [>] Email address for Nginx Proxy Manager: " NPM_INITIAL_ADMIN_EMAIL
  sed -i "s/__NPM_INITIAL_ADMIN_EMAIL__/$NPM_INITIAL_ADMIN_EMAIL/g" "${__NPM_COMPOSE_FILE}"

  read -sp "  [>] Intial Password for Nginx Proxy Manager: " NPM_INITIAL_ADMIN_PASSWORD
  echo
  sed -i "s/__NPM_INITIAL_ADMIN_PASSWORD__/$NPM_INITIAL_ADMIN_PASSWORD/g" "${__NPM_COMPOSE_FILE}"
  echo -e "${RESET}"

  echo -e "${GREEN}  ;;----------------------------------------------------------------------------${RESET}"
  echo -e "${GREEN}  [+] Nginx Proxy Manager has been configured!${RESET}"

  COMMAND+=" \\
    -f compose.reverse-proxy.yaml"
}

complete() {
  date > "$MARKER_FILE"

  COMMAND+=" \\
    up -d"

  echo -e "${YELLOW}"
  cat << "EOF"
  
   |\__/,|   (`\     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
   |_ _  |.--.) )    | Self-Hosted Monitoring Stack is good to go!             |
   ( T   )     /     | Run the command below to get started                    |
  (((^_(((/(((_/     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
EOF
  echo -e "${RESET}${GREEN}"
  echo -e "${COMMAND}"
  echo -e "${RESET}"
}



#### ------------------------------------------------------ ENTRYPOINT 

main() {
  banner
  check_marker
  initialize_postgresql
  configure_grafana
  configure_mikrotik_exporter
  ask_for_npm

  complete
}

main