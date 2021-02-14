# How to install

From [this](https://github.com/BrotherPatrix/my-tutorials/tree/master/valheim-server-ubuntu-20-04) tutorial a script was created.
Same prerequisets are applied:
- Stable internet connection;
- Configurable router that permits you to expose ports;
- Dedicated machine or virtual machine running Ubuntu 20.04 either Desktop or Server(Recommended);

There are two main files:
- install.sh
- uninstall.sh

**ATTENTION!** Both scripts were designed to run under root or super user via `sudo` command, mostly because you can see in the tutorial that a lot of commands need privileges to install. Also you can see that the user is `valheim`(not `steam`), with home directory `/opt/valheim` and data folder `/var/lib/valheim`.

## How to install
```bash
sudo ./install.sh
```
This command will use the default configuration and will generate a random password.
If you want to configure it, you can run with `--help` to check available options:
```bash
sudo ./install.sh --help
```
Output:
```
This is an install bash script for a Valheim Server.

Syntax: ./install.sh [-h|n|p|pb|wn|pw]
options:
-h |--help
  Print help.
-n |--name
  Set the server name - Default: "My Valheim Server"
-p |--port
  Set the server port - Default: 2456
-pb|--public
  Set the server port - Default: 1
-wn|--world-name
  Set the world name - Default: "Dedicated"
-pw|--password
  Set the password - Default: <random_16> NOTE: this will pe printed and saved in a file.
```
Sample:
```bash
sudo ./install.sh -n 'Test Server' -p 2459 -pb 0 -wn 'TestWorld' -pw 'TestPassword098'
```
**NOTE!** I'd recommend not adding the password, because the generated one is secure enough. It is actually recommended actually to change the password once in a while on the `/opt/valheim/start_valheim_server.sh` script.

## How to uninstall
Just run the script:
```bash
sudo ./unistall.sh
```
Output:
```
[INFO] - Checking if there is a service.
[INFO] - Found service! Attempting to remove it before uninstall...
Removed /etc/systemd/system/multi-user.target.wants/valheim-server.service.
userdel: valheim mail spool (/var/mail/valheim) not found
[SUCC] - Finished uninstalling!
```
# THE END