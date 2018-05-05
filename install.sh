#!/bin/bash -e

function usage() {
    cat <<EOF
usage: ./install.sh [-h|--help] [game-dir]

    game-dir  - Path to install. Defaults to '\$HOME/Games/Warframe'
    -h --help - Display this help message

Environment Variables:

The following environment variables will be preserved when later running the game:

    WINE      - Path to custom Wine executable. Defaults to 'wine64'
    WINEARCH  - Override Wine execution architecture. Currently, only 'win64' is supported.
    WINEDEBUG - Wine debugging settings. Defaults to '-all', all messages off.

EOF
}

if [ $# -gt 0 ]; then
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
	usage
	exit 0
    fi
fi

GAMEDIR="${1:-${HOME}/Games/Warframe}"

WFDIR="$GAMEDIR/drive_c/Program Files/Warframe"

WINE=${WINE:-wine64}
export WINEARCH=${WINEARCH:-win64}
export WINEDEBUG=${WINEDEBUG:--all}
export WINEPREFIX="$GAMEDIR"

echo "*************************************************"
echo "Creating wine prefix and performing winetricks."
echo "*************************************************"

mkdir -p "$GAMEDIR"
winetricks -q vcrun2015 vcrun2013 devenum xact xinput quartz win7

echo "*************************************************"
echo "Applying warframe wine prefix registry settings."
echo "*************************************************"
$WINE regedit /S wf.reg

echo "*************************************************"
echo "Creating warframe directories."
echo "*************************************************"
mkdir -p "$WFDIR"
mkdir -p "${GAMEDIR}/drive_c/users/${USER}/Local Settings/Application Data/Warframe"

echo "*************************************************"
echo "Copying warframe files."
echo "*************************************************"
cp EE.cfg "${GAMEDIR}/drive_c/users/${USER}/Local Settings/Application Data/Warframe/EE.cfg"

cp -R updater.sh README.md "$WFDIR"

pushd "$WFDIR"

cat > uninstall.sh <<EOF
#!/bin/bash

if [ -e /usr/bin/warframe ]; then
	sudo rm -R /usr/bin/warframe
fi
rm -R "\$HOME/Desktop/warframe.desktop" "$GAMEDIR" \\
      "\$HOME/.local/share/applications/warframe.desktop"
echo "Warframe has been successfully removed."
EOF

chmod a+x updater.sh
chmod a+x uninstall.sh

echo "*************************************************"
echo "Installing Direct X."
echo "*************************************************"
wget https://download.microsoft.com/download/8/4/A/84A35BF1-DAFE-4AE8-82AF-AD2AE20B6B14/directx_Jun2010_redist.exe
$WINE directx_Jun2010_redist.exe /Q /T:C:\dx9
$WINE dx9/dx9/DXSETUP.EXE /silent
rm -R dx9


echo "*************************************************"
echo "Creating warframe shell script"
echo "*************************************************"

cat > warframe.sh <<EOF
#!/bin/bash

export PULSE_LATENCY_MSEC=60
export __GL_THREADED_OPTIMIZATIONS=1
export MESA_GLTHREAD=TRUE
export __PBA_GEO_HEAP=2048

export WINE=$WINE
export WINEARCH=$WINEARCH
export WINEDEBUG=$WINEDEBUG
export WINEPREFIX="$WINEPREFIX"

cd "$WFDIR"
exec ./updater.sh "\$@"
EOF

chmod a+x warframe.sh

# Errors are now tolerable
set +e

echo "*************************************************"
echo "The next few steps will prompt you for shortcut creations. If root is required, please enter your root password when prompted."
echo "*************************************************"

read -p "Would you like to add warframe to the default path? y/n" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
	sudo cp "$WFDIR/warframe.sh" /usr/bin/warframe
fi

popd &>/dev/null

function mkdesktop() {
	cat <<EOF
[Desktop Entry]
Encoding=UTF-8
Name=Warframe
GenericName=Warframe
Exec="$WFDIR/warframe.sh"
Icon="$WFDIR/warframe.png"
StartupNotify=true
Terminal=false
Type=Application
Categories=Application;Game
EOF
}

# Download warframe.png icon for creating shortcuts
wget -O warframe.png http://i.imgur.com/lh5YKoc.png -q

read -p "Would you like a menu shortcut? y/n" -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then

	echo "*************************************************"
	echo "Creating warframe application menu shortcut."
	echo "*************************************************"
	cp warframe.png "$WFDIR"
	mkdesktop > "$HOME/.local/share/applications/warframe.desktop"
fi

read -p "Would you like a desktop shortcut? y/n" -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
	echo "*************************************************"
	echo "Creating warframe desktop shortcut."
	echo "*************************************************"
	cp warframe.png "$WFDIR"
	mkdesktop > "${HOME}/Desktop/warframe.desktop"
fi


echo "*************************************************"
echo "Installation complete! It is safe to delete this folder."
echo "*************************************************"
