#!/bin/sh
export PROTON_NO_ESYNC=1
export STEAM_COMPAT_DATA_PATH="/home/snake/.steam/steam/steamapps/compatdata/107410"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="${HOME}/.steam/steam"
"${HOME}/.steam/steam/steamapps/common/Proton 8.0/proton" run "${HOME}/.steam/steam/steamapps/common/Arma 3/Arma3Launcher.exe"

