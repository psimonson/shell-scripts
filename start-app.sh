#!/bin/sh

exec_steamapp() {
	local steamapps_path="/home/$USER/.steam/steam/steamapps"
	local compatdata_path="${steamapps_path}/compatdata/$1"
	local app_path="$2"

	if [[ -x "$compatdata_path" ]]
	then
		export STEAM_COMPAT_CLIENT_INSTALL_PATH="$steamapps_path"
		export STEAM_COMPAT_DATA_PATH="$compatdata_path"
		"${steamapps_path}/compatibilitytools.d/GE-Proton9-25/proton" run "${app_path}"
	else
		echo "Game or app not found."
	fi
}

if [ "$#" = "2" ]
then
	exec_steamapp "$1" "$2"
else
	echo "Usage: $0 <gameappid> <program-to-run>"
fi

