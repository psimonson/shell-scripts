#!/bin/sh

exec_steamapp() {
	local steamapps_path="${HOME}/.steam/steam/steamapps"
	local compatdata_path="${steamapps_path}/compatdata/$1"
	local app_path="$2"

	if [[ -x "$app_path" && -x "$compatdata_path" ]]
	then
		export STEAM_COMPAT_CLIENT_INSTALL_PATH="$steamapps_path"
		export STEAM_COMPAT_DATA_PATH="$compatdata_path"
		"${steamapps_path}/common/Proton 8.0/proton" run "${app_path}"
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
