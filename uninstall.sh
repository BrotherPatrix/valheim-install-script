#!/bin/bash

log() {
	ERROR=$'\e[1;31m'
	SUCC=$'\e[1;32m'
	WARN=$'\e[1;33m'
	INFO=$'\e[1;34m'
	end=$'\e[0m'
	printf "%s[%s] - $2${end}\n" "${!1}" "$1"
	if [ -n "$3" ]; then exit "$3"; fi
}

log INFO "Checking if there is a service."
systemctl is-active --quiet valheim-server
if [[ $? -eq 0 ]]; then
	log INFO "Found service! Attempting to remove it before uninstall..."
	systemctl stop valheim-server.service || log ERROR "Could not stop service!" 1
	systemctl disable valheim-server.service || log ERROR "Could not disable service!" 1
	rm -f /lib/systemd/system/valheim-server.service || log ERROR "Could not delete systemd service file!" 1
fi
userdel -r valheim || log ERROR "Could not delete valheim user!" 1
rm -rf /var/lib/valheim || log ERROR "Could not remove data folder /var/lib/valheim!" 1
rm -rf /etc/valheim || log ERROR "Could not delete config folder!" 1

log SUCC "Finished uninstalling!" 0
