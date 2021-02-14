#!/bin/bash

log() {
	ERROR=$'\e[1;31m'
	SUCC=$'\e[1;32m'
	WARN=$'\e[1;33m'
	INFO=$'\e[1;34m'
	end=$'\e[0m'
	printf "${!1}[$1] - $2${end}\n"
	if [ ! -z $3 ]; then exit $3; fi
}

randpw() {
	tr </dev/urandom -dc _A-Z-a-z-0-9 | head -c"${1:-16}"
	echo
}

usage() {
	echo "This is an install bash script for a Valheim Server."
	echo
	echo "Syntax: $0 [-h|n|p|pb|wn|pw]"
	echo "options:"
	
	echo "-h |--help"
	echo "  Print help."

	echo "-n |--name"
	echo '  Set the server name - Default: "My Valheim Server"'
	
	echo "-p |--port"
	echo '  Set the server port - Default: 2456'
	
	echo "-pb|--public"
	echo '  Set the server port - Default: 1'

	echo "-wn|--world-name"
	echo '  Set the world name - Default: "Dedicated"'

	echo "-pw|--password"
	echo '  Set the password - Default: <random_16> NOTE: this will pe printed and saved in a file.'

	echo ""
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
		usage
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
apt install software-properties-common || log ERROR "Could not install software-properties-common!" 1
add-apt-repository multiverse || log ERROR "Could not add multiverse apt repository!" 1
dpkg --add-architecture i386 || log ERROR "Cloud not add i386 arhitecture!" 1
apt update || log ERROR "Could not update repository" 1
apt install lib32gcc1 steamcmd  || log ERROR "Could not install other decepencies." 1

log INFO "Creating steam user..."
useradd -m -d /opt/valheim -s /bin/bash valheim || log ERROR "Could not create valheim user!" 1

log INFO "Create savefiles directory"
mkdir -p /var/lib/valheim || log ERROR "Could not create valheim savefiles folder!" 1
chown -R valheim:valheim /var/lib/valheim

runuser -l valheim -c 'ln -s /usr/games/steamcmd steamcmd' || log ERROR "Could not create steamcmd symbolic link for valheim user!" 1
runuser -l valheim -c 'steamcmd +login anonymous +force_install_dir /opt/valheim/server +app_update 896660 validate +quit' || log ERROR "Could not download valheim dedicated server via steamcmd!" 1

log INFO "Creating service start command script..."
echo '#!/bin/bash' > /opt/valheim/start_valheim_server.sh  || log ERROR "Script write error!" 1
echo "./opt/valheim/server/valheim_server.x86_64 \\"  >> /opt/valheim/start_valheim_server.sh  || log ERROR "Script write error!" 1
echo "  -name \"${SERVER_NAME}\" \\"  >> /opt/valheim/start_valheim_server.sh || log ERROR "Script write error!" 1
echo "  -port 2456 -world \"${SERVER_WORLD_NAME}\" \\" >> /opt/valheim/start_valheim_server.sh  || log ERROR "Script write error!" 1
echo "  -password \"${SERVER_PASSWORD}\" \\" >> /opt/valheim/start_valheim_server.sh || log ERROR "Script write error!" 1
echo "  -public ${SERVER_PUBLIC} \\" >> /opt/valheim/start_valheim_server.sh || log ERROR "Script write error!" 1
echo '  -savedir "/var/lib/valheim"' >> /opt/valheim/start_valheim_server.sh || log ERROR "Script write error!" 1
echo "" >> /opt/valheim/start_valheim_server.sh || log ERROR "Script write error!" 1

chown valheim:valheim /opt/valheim/start_valheim_server.sh || log ERROR "Could not change owner to valheim user!" 1
runuser -l valheim -c 'chmod o+x /opt/valheim/start_valheim_server.sh' || log ERROR "Could not make it executable!" 1

log INFO "Creating service stop command script..."
echo '#!/bin/bash' > /opt/valheim/stop_valheim_server.sh  || log ERROR "Script write error!" 1
echo 'echo 1 > /opt/valheim/server/server_exit.drp'  >> /opt/valheim/stop_valheim_server.sh  || log ERROR "Script write error!" 1
echo "" >> /opt/valheim/stop_valheim_server.sh || log ERROR "Script write error!" 1

chown valheim:valheim /opt/valheim/stop_valheim_server.sh || log ERROR "Could not change owner to valheim user!" 1
runuser -l valheim -c 'chmod o+x /opt/valheim/stop_valheim_server.sh' || log ERROR "Could not make it executable!" 1

log INFO "Creating service systemd file..."
echo '[Unit]' > /lib/systemd/system/valheim-server.service || log ERROR "Script write error!" 1
echo 'Description=Valheim Server Service' >> /lib/systemd/system/valheim-server.service || log ERROR "Script write error!" 1
echo '[Service]' >> /lib/systemd/system/valheim-server.service || log ERROR "Script write error!" 1
echo 'Environment="LD_LIBRARY_PATH=/opt/valheim/server/linux64:$LD_LIBRARY_PATH"' >> /lib/systemd/system/valheim-server.service || log ERROR "Script write error!" 1
echo 'Environment="SteamAppId=892970"' >> /lib/systemd/system/valheim-server.service || log ERROR "Script write error!" 1
echo 'ExecStartPre=/opt/valheim/steamcmd +login anonymous +force_install_dir /opt/valheim/server +app_update 896660 validate +quit' >> /lib/systemd/system/valheim-server.service || log ERROR "Script write error!" 1
echo 'ExecStart=/bin/bash /opt/valheim/start_valheim_server.sh' >> /lib/systemd/system/valheim-server.service || log ERROR "Script write error!" 1
echo 'ExecStop=/bin/bash /opt/valheim/stop_valheim_server.sh' >> /lib/systemd/system/valheim-server.service || log ERROR "Script write error!" 1
echo 'User=valheim' >> /lib/systemd/system/valheim-server.service || log ERROR "Script write error!" 1
echo 'Restart=always' >> /lib/systemd/system/valheim-server.service || log ERROR "Script write error!" 1
echo '[Install]' >> /lib/systemd/system/valheim-server.service || log ERROR "Script write error!" 1
echo 'WantedBy=multi-user.target' >> /lib/systemd/system/valheim-server.service || log ERROR "Script write error!" 1
echo '' >> /lib/systemd/system/valheim-server.service || log ERROR "Script write error!" 1

systemctl enable valheim-server.service || log ERROR "Could not enable service!" 1
systemctl start valheim-server.service || log ERROR "Could not start service!" 1

log SUCC "Finished installing valheim server! Your server information:"

printf "SERVER_NAME=%s\n" "${SERVER_NAME}"
printf "SERVER_WORLD_NAME=%s\n" "${SERVER_WORLD_NAME}"
printf "SERVER_PORT=%s\n" "${SERVER_PORT}"
printf "SERVER_PASSWORD=%s\n" "${SERVER_PASSWORD}"
printf "SERVER_PUBLIC=%s\n" "${SERVER_PUBLIC}"

log INFO "Make sure to copy the above information. Bye!" 0
