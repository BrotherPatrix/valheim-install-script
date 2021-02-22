#!/bin/bash

log() {
	ERROR=$'\e[1;31m';
	SUCC=$'\e[1;32m';
	WARN=$'\e[1;33m';
	INFO=$'\e[1;34m';
	end=$'\e[0m';
	printf "%s[%s] - $2${end}\n" "${!1}" "$1";
	if [ -n "$3" ]; then exit "$3"; fi;
}

randpw() {
	printf "%s" "$(tr </dev/urandom -dc _A-Z-a-z-0-9 | head -c"${1:-16}")"
}

usage() {
	printf "This is an install script for a Valheim Server.\n";
	printf "Syntax: %s [-h|n|p|pb|wn|pw]\n" "$0"
	printf "options:\n"
	printf "\t-h |--help\n"
	printf "\t\tPrint help.\n"
	printf "\t-n |--name\n"
	printf "\t\tSet the server name - Default: \"My Valheim Server\"\n"
	printf "\t-p |--port\n"
	printf "\t\tSet the server port - Default: 2456\n"
	printf "\t-pb|--public\n"
	printf "\t\tSet the server port - Default: 1\n"
	printf "\t-wn|--world-name\n"
	printf "\t\tSet the world name - Default: \"Dedicated\"\n"
	printf "\t-pw|--password\n"
	printf "\t\tSet the password - Default: <random 16>\n"
	exit 0;
}

SERVER_NAME="My Valheim Server"
SERVER_WORLD_NAME="Dedicated"
SERVER_PORT="2456"
SERVER_PASSWORD=$(randpw)
SERVER_PUBLIC=1

POSITIONAL=()
while [[ $# -gt 0 ]]; do
	key="$1"

	case $key in
	-h | --help)
		usage "$@"
		;;
	-n | --name)
		SERVER_NAME="$2"
		shift
		shift
		;;
	-p | --port)
		SERVER_PORT="$2"
		shift
		shift
		;;
	-pb | --public)
		SERVER_PUBLIC="$2"
		shift
		shift
		;;
	-wn | --world-name)
		SERVER_WORLD_NAME="$2"
		shift
		shift
		;;
	-pw | --password)
		SERVER_PASSWORD="$2"
		shift
		shift
		;;
	*)
		POSITIONAL+=("$1")
		shift
		;;
	esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

log INFO "SERVER_NAME=${SERVER_NAME}"
log INFO "SERVER_WORLD_NAME=${SERVER_WORLD_NAME}"
log INFO "SERVER_PORT=${SERVER_PORT}"
log INFO "SERVER_PASSWORD=${SERVER_PASSWORD}"
log INFO "SERVER_PUBLIC=${SERVER_PUBLIC}"

os_release_file=/etc/os-release
os_release=

if test -f "$os_release_file"; then
	log INFO "$os_release_file exists. Cheking OS..."
	os_release=$(cat $os_release_file | grep "VERSION_ID=" | cut -d'=' -f2 | sed -e 's/^"//' -e 's/"$//')
	log INFO "Discovered OS: ${os_release%\"}"
	if [ "$os_release" != "20.04" ]; then
		log ERROR "Only Ubuntu 20.04 is suported." 2
	fi
else
	log ERROR "OS release file not present! Probably you are trying to install on an unsuported OS." 1
fi

log INFO "Installing dependencies via apt ..."
apt install software-properties-common -y || log ERROR "Could not install software-properties-common!" 1
add-apt-repository multiverse || log ERROR "Could not add multiverse apt repository!" 1
dpkg --add-architecture i386 || log ERROR "Cloud not add i386 arhitecture!" 1
apt update || log ERROR "Could not update repository" 1
apt install lib32gcc1 steamcmd -y || log ERROR "Could not install other decepencies." 1

log INFO "Creating steam user..."
useradd -m -d /opt/valheim -s /bin/bash valheim || log ERROR "Could not create valheim user!" 1

log INFO "Create savefiles directory"
mkdir -p /var/lib/valheim || log ERROR "Could not create valheim savefiles folder!" 1
chown -R valheim:valheim /var/lib/valheim || log ERROR "Could not give permissions to valheim user for /var/lib/valheim !" 1

runuser -l valheim -c 'ln -s /usr/games/steamcmd steamcmd' || log ERROR "Could not create steamcmd symbolic link for valheim user!" 1
runuser -l valheim -c 'steamcmd +login anonymous +force_install_dir /opt/valheim/server +app_update 896660 validate +quit' || log ERROR "Could not download valheim dedicated server via steamcmd!" 1

mkdir -p /etc/valheim || log ERROR "Could not create valheim config file!" 1
{
	printf "SteamAppId=892970\n"
	printf "LD_LIBRARY_PATH=/opt/valheim/server/linux64:\$LD_LIBRARY_PATH"
	printf "\n"
	printf "VALHEIM_SERVER_NAME=%s\n" "${SERVER_NAME}"
	printf "VALHEIM_SERVER_WORLD_NAME=%s\n" "${SERVER_WORLD_NAME}"
	printf "VALHEIM_SERVER_PORT=%s\n" "${SERVER_PORT}"
	printf "VALHEIM_SERVER_PASSWORD=%s\n" "${SERVER_PASSWORD}"
	printf "VALHEIM_SERVER_PUBLIC=%s\n" "${SERVER_PUBLIC}"
} >/etc/valheim/config.properties || log ERROR "Could not create config file!" 1
chown -R valheim:valheim /etc/valheim || log ERROR "Could not give permissions to valheim user for /etc/valheim !" 1

log INFO "Creating service start command script..."
cat start_valheim_server.sh.template >/opt/valheim/start_valheim_server.sh || log ERROR "Could not create start script!" 1
chown valheim:valheim /opt/valheim/start_valheim_server.sh || log ERROR "Could not change owner to valheim user for the start script!" 1
runuser -l valheim -c 'chmod o+x /opt/valheim/start_valheim_server.sh' || log ERROR "Could not make start script executable!" 1

log INFO "Creating service stop command script..."
cat stop_valheim_server.sh.template >/opt/valheim/stop_valheim_server.sh || log ERROR "Could not create stop script!" 1
chown valheim:valheim /opt/valheim/stop_valheim_server.sh || log ERROR "Could not change owner to valheim user for the stop script!" 1
runuser -l valheim -c 'chmod o+x /opt/valheim/stop_valheim_server.sh' || log ERROR "Could not make stop script executable!" 1

log INFO "Creating service systemd file..."
cat valheim-server.service.template >/lib/systemd/system/valheim-server.service || log ERROR "Could not create systemd service file!" 1

systemctl enable valheim-server.service || log ERROR "Could not enable service!" 1
systemctl start valheim-server.service || log ERROR "Could not start service!" 1

log INFO "Configuration available at /opt/valheim/config"

log SUCC "Finished installing your valheim server!" 0
