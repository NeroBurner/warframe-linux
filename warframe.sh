#!/bin/bash
# exit on first error
set -e

function print_synopsis {
	echo "$0 [options]"
	echo ""
	echo "options:"
	echo "    --download-dir      override default download_dir variable"
	echo "    --wine-prefix       override default WINEPREFIX variable"
	echo "    --email             override default user_email variable"
	echo "    --winecfg           start winecfg with the current wine bottle"
	echo "    --regedit           start regedit with the current wine bottle"
	echo "    -w, --winetricks    install packages to wine bottle, don't launch game"
	echo "    -r, --registry      update wine registry, don't launch game"
	echo "    -c, --config        create basic warframe configuration file inside wine bottle"
	echo "    -i, --install       same as defining"
	echo "                        '--winetricks --registry and --config"
	echo "    --dxvk              choose dxvk wine prefix"
	echo "    --install-dxvk      install vulkansdk and install dxvk into dxvk prefix"
	echo "    --disable-dxvk      remove wine-vulkan registry entries"
	echo "    --install-bin       install script to /usr/bin (uses sudo for root access)."
	echo "                        Replaces 'download_dir' and 'WINEPREFIX' with"
	echo "                        overrides."
	echo "    --menu-shortcut     create menu entry (uses sudo for root access)"
	echo "    --desktop-shortcut  create desktop shortcut (requires --menu-shortcut"
	echo "                        for installation of warframe icon)"
	echo "    --install-system    same as defining"
	echo "                        '--install-bin --menu-shortcut and --desktop-shortcut'"
	echo "    --uninstall-system  remove all the files installed by --install-system"
	echo "    --full-update       download all of the indexed files."
	echo "    --no-update         explicitly disable updating of warframe."
	echo "    --no-cache          explicitly disable cache optimization of warframe cache files."
	echo "    --no-game           explicitly disable launching of warframe."
	echo "    --32bit             use 32bit wine bottle and 32bit Warframe"
	echo "    -v, --verbose       print each executed command"
	echo "    -h, --help          print this help message and quit"
}

#############################################################
# user defined constants
#############################################################
# wine bottles, script will append '_dxvk' when enabled
export WINEPREFIX="/home/$USER/Games/Warframe/wine_prefix"

# specify the download folder, where all the game files are
download_dir="/home/$USER/Games/Warframe/Downloaded"

# your email, used in basic warframe config creation
user_email=""

#############################################################
# default values
#############################################################
do_update=true
do_cache=true
start_game=true
install_dxvk=false
do_dxvk=false
disable_dxvk=false
use_x64=true

#############################################################
# parse command line arguments
#############################################################
# As long as there is at least one more argument, keep looping
while [[ $# -gt 0 ]]; do
	key="$1"
	case "$key" in
		--wine-prefix)
		if [ -z "$2" ]; then
			echo "option '$key' needs a value"
			print_synopsis
			exit 1
		fi
		WINEPREFIX="$2"
		shift # past argument
		;;
		--download-dir)
		if [ -z "$2" ]; then
			echo "option '$key' needs a value"
			print_synopsis
			exit 1
		fi
		download_dir="$2"
		shift # past argument
		;;
		--email)
		if [ -z "$2" ]; then
			echo "option '$key' needs a value"
			print_synopsis
			exit 1
		fi
		user_email="$2"
		shift # past argument
		;;
		--winecfg)
		start_winecfg=true
		;;
		--regedit)
		start_regedit=true
		;;
		-w|--winetricks)
		do_winetricks=true
		do_update=false
		do_cache=false
		start_game=false
		;;
		-r|--registry)
		do_registry=true
		do_update=false
		do_cache=false
		start_game=false
		;;
		-c|--config)
		do_config=true
		do_update=false
		do_cache=false
		start_game=false
		;;
		-i|--install)
		do_winetricks=true
		do_registry=true
		do_config=true
		do_update=false
		do_cache=false
		start_game=false
		;;
		--install-dxvk)
		do_update=false
		do_cache=false
		start_game=false
		do_dxvk=true
		install_dxvk=true
		;;
		--dxvk)
		do_dxvk=true
		;;
		--disable-dxvk)
		do_update=false
		do_cache=false
		start_game=false
		do_dxvk=true
		disable_dxvk=true
		;;
		--full-update)
		full_update=true
		;;
		--no-update)
		do_update=false
		;;
		--no-cache)
		do_cache=false
		;;
		--no-game)
		start_game=false
		;;
		--install-bin)
		do_install_bin=true
		do_update=false
		do_cache=false
		start_game=false
		;;
		--menu-shortcut)
		do_menu_shortcut=true
		do_update=false
		do_cache=false
		start_game=false
		;;
		--desktop-shortcut)
		do_desktop_shortcut=true
		do_update=false
		do_cache=false
		start_game=false
		;;
		--install-system)
		do_install_bin=true
		do_menu_shortcut=true
		do_desktop_shortcut=true
		do_update=false
		do_cache=false
		start_game=false
		;;
		--uninstall-system)
		do_uninstall_system=true
		do_update=false
		do_cache=false
		start_game=false
		;;
		--32bit)
		use_x64=false
		;;
		-v|--verbose)
		verbose=true
		;;
		-h|--help)
		print_synopsis
		exit 0
		;;
		*)
		echo "Unknown option '$key'"
		print_synopsis
		exit 1
		;;
	esac
	# Shift after checking all the cases to get the next option
	shift
done

# show all executed commands
if [ "$verbose" = true ] ; then
	set -x
fi

#############################################################
# define variables
#############################################################
export __PBA_GEO_HEAP=2048
export PULSE_LATENCY_MSEC=60
export __GL_THREADED_OPTIMIZATIONS=1
export MESA_GLTHREAD=TRUE

export MSI="${download_dir}/Public/Warframe.msi"
export LAUNCHER="${download_dir}/Public/Tools/Launcher.exe"
warframe_exe_base="${download_dir}/Public"


# always use 64bit prefix, but start 32bit binary
export WINEARCH=win64
WINECMD=wine64
# distinction between 32bit and 64bit
if [ "$use_x64" = true ] ; then
	export WARFRAME="${warframe_exe_base}/Warframe.x64.exe"
else
	#export WINEARCH=win32
	export WARFRAME="${warframe_exe_base}/Warframe.exe"
	#WINECMD=wine
fi
if [ "$do_dxvk" = true ] ; then
	export WINEPREFIX="${WINEPREFIX}_dxvk"
	export RADV_DEBUG=nohiz
fi


# folder where warframe saves its configuration and launcher
warframe_config_dir="${WINEPREFIX}/drive_c/users/${USER}/Local Settings/Application Data/Warframe"
config_file="${warframe_config_dir}/EE.cfg"

#############################################################
# start specified program and then exit, good for debugging
#############################################################
if [ "$start_winecfg" = true ] ; then
	echo "calling winecfg and exit this script afterwards"
	winecfg
	exit 0
fi
if [ "$start_regedit" = true ] ; then
	echo "calling regedit and exit this script afterwards"
	regedit
	exit 0
fi

#############################################################
# essential wine-prefix preparation
#############################################################
if [ "$do_winetricks" = true ] ; then
	echo "*************************************************"
	echo "Installing Direct X."
	echo "*************************************************"
	# create download-dir if it does not exist yet
	mkdir -p "${download_dir}"
	# full path to directx installer
	dx_redist="${download_dir}/directx_Jun2010_redist.exe"
	if [ ! -f "${dx_redist}" ]; then
		wget https://download.microsoft.com/download/8/4/A/84A35BF1-DAFE-4AE8-82AF-AD2AE20B6B14/directx_Jun2010_redist.exe -O "${dx_redist}"
	fi
	prefix_drive_c="${WINEPREFIX}/drive_c"
	# create dx9 extraction dir if it does not yet exist
	mkdir -p "${prefix_drive_c}/dx9"
	# extract directx installer
	WINEDEBUG=-all $WINECMD "${dx_redist}" /Q /T:C:\dx9
	# install directx
	WINEDEBUG=-all $WINECMD "${prefix_drive_c}/dx9/dx9/DXSETUP.EXE" /silent
	# remove extracted folder
	rm -R "${prefix_drive_c}/dx9"

	echo "using winetricks to install needed packages"
	# - winetricks for Warframe
	# with wine 2.21-staging only those two packages are needed
	# 20180105 - add win7: with winXP only dx9 is supported, with win7 dx10 is available
	winetricks -q vcrun2015 vcrun2013 devenum xact xinput quartz win7
	# from the lutris installer the following packages were installed
	#winetricks -q vcrun2015 xact xinput win7 hosts
fi

#############################################################
# update wine registry
#############################################################
if [ "$do_registry" = true ] ; then
	reg_file="/tmp/wf.reg"
	# transform absolute linux path to absolute Windows path for registy
	download_dir_windows="z:$(echo "${download_dir}" | sed 's/\//\\\\/g')"
	echo "update windows registry, creating temporary file at '$reg_file'"
	if [ "$use_x64" = true ] ; then
		Enable64Bit="dword:00000001"
	else
		Enable64Bit="dword:00000000"
	fi
	# create registry file
	cat <<EOF > "$reg_file"
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\\Software\\Wine\\Direct3D]
"OffscreenRenderingMode"="fbo"
"RenderTargetLockMode"="readtex"

[HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides]
"rasapi32"="native"
"d3dcompiler_43"="native,builtin"
"d3dcompiler_47"="native,builtin"
"xaudio2_7"="native,builtin"
EOF
	# update registry to set warframe download folder and other wine options
	$WINECMD regedit /S "${reg_file}"
fi

#############################################################
# create warframe config file
#############################################################
if [ "$do_config" = true ] ; then
	echo "create basic configuration file '$config_file'"
	# create folder if they don't exist
	mkdir -p "$warframe_config_dir"
	# write basic configurations
	cat <<EOF > "$config_file"
+nowarning
+version=5

[KeyBindings,/EE/Types/Input/KeyBindings]

[LotusDedicatedServerAccountSettings,/Lotus/Types/Game/DedicatedServerAccountSettings]
email=${user_email}

[LotusWindows_KeyBindings,/Lotus/Types/Input/KeyBindings]

[Windows_Config,/EE/Types/Base/Config]
Stats.Visible=1
Graphics.AnisotropicFiltering=AF_16X
Graphics.AutoDetectGraphicsSettings=0
Graphics.BlurLocalReflections=0
Graphics.Borderless=1
Graphics.Brightness=1.4540318
Graphics.Contrast=0.99721003
Graphics.DynamicResolution=DYNRES_USER
Graphics.EnableDOF=0
Graphics.EnableMotionBlur=0
Graphics.EnableTessellation=0
Graphics.EnableVolumetricLighting=0
Graphics.GeometryDetail=GD_HIGH
Graphics.LocalReflections=0
Graphics.MaxFrameRate=72
Graphics.ParticleSysQuality=PQ_HIGH
Graphics.ShadowQuality=SQ_HIGH
Graphics.TextureQuality=TQ_HIGH
Graphics.TrilinearFiltering=TF_ON
Graphics.VSyncMode=VSM_NEVER_SYNC
Client.Email=${user_email}
EOF
fi

#############################################################
# install-system section
#############################################################
if [ "$do_install_bin" = true ] ; then
	system_bin_file="/usr/bin/warframe"
	tmp_bin_file="/tmp/warframe"
	cp "$0" "$tmp_bin_file"
	# replace default values with the overridden ones
	sed -i '/^export WINEPREFIX=/s#.*#'"export WINEPREFIX=\"${WINEPREFIX}\"#" "${tmp_bin_file}"
	sed -i '/^download_dir=/s#.*#'"download_dir=\"${download_dir}\"#" "${tmp_bin_file}"
	sed -i '/^user_email=/s#.*#'"user_email=\"${user_email}\"#" "${tmp_bin_file}"
	echo "installing this script as '${system_bin_file}'"
	# install script in search path
	sudo cp "$tmp_bin_file" "$system_bin_file"
fi

# variables for desktop file creation
menu_tmp_file="/tmp/warframe.desktop"
applications_dir="/usr/share/applications"
desktop_icon="/usr/share/pixmaps/warframe.png"
if [ "$do_dxvk" = true ] ; then
	desktop_name="Warframe dxvk"
	desktop_exec="/usr/bin/warframe --dxvk \"\$@\""
	menu_file="${applications_dir}/warframe-dxvk.desktop"
	desktop_file="/home/$USER/Desktop/warframe-dxvk.desktop"
else
	desktop_name="Warframe 64bit"
	desktop_exec="/usr/bin/warframe \"\$@\""
	menu_file="${applications_dir}/warframe64.desktop"
	desktop_file="/home/$USER/Desktop/warframe64.desktop"
fi
function create_desktop_file {
	cat <<EOF > "$menu_tmp_file"
[Desktop Entry]
Encoding=UTF-8
Name=${desktop_name}
GenericName=Warframe
Warframe
Exec=${desktop_exec}
Icon=${desktop_icon}
StartupNotify=true
Terminal=false
Type=Application
Categories=Application;Game
EOF
}

if [ "$do_menu_shortcut" = true ] ; then
	echo "download warframe.png icon for creating shortcuts"
	# Download warframe.png icon for creating shortcuts
	wget -O warframe.png http://i.imgur.com/lh5YKoc.png -q
	echo "copy warframe icon to '${desktop_icon}'"
	sudo cp warframe.png ${desktop_icon}

	echo "creating menu shortcut for warframe at '${menu_file}'"
	# create temporary desktop entry file
	create_desktop_file
	# copy desktop entry file to its right position
	sudo cp "$menu_tmp_file" "$menu_file"
fi

if [ "$do_desktop_shortcut" = true ] ; then
	echo "creating desktop shortcut at '${desktop_file}'"
	# create temporary desktop entry file
	create_desktop_file
	# copy desktop entry file to the desktop
	cp "$menu_tmp_file" "$desktop_file"
fi

#############################################################
# uninstall files installed by --install-system
#############################################################
if [ "$do_uninstall_system" = true ] ; then
	echo "removing icon file '${desktop_icon}'"
	sudo rm -f "$desktop_icon"
	echo "removing menu file '${menu_file}'"
	sudo rm -f "$menu_file"
	echo "removing desktop file '${desktop_file}'"
	rm -f "$desktop_file"
	echo "removing script '${system_bin_file}'"
	sudo rm -f "$menu_file"
fi

#############################################################
# enable dxvk
#############################################################
if [ "$install_dxvk" = true ] ; then
	# install dxvk 32 and 64 bit
	mkdir -p dxvk/win64 dxvk/win32
	curl https://haagch.frickel.club/files/dxvk/latest/64/bin/dxgi.dll      -o dxvk/win64/dxgi.dll
	curl https://haagch.frickel.club/files/dxvk/latest/64/bin/d3d11.dll     -o dxvk/win64/d3d11.dll
	curl https://haagch.frickel.club/files/dxvk/latest/64/bin/setup_dxvk.sh -o dxvk/win64/setup_dxvk.sh
	curl https://haagch.frickel.club/files/dxvk/latest/32/bin/dxgi.dll      -o dxvk/win32/dxgi.dll
	curl https://haagch.frickel.club/files/dxvk/latest/32/bin/d3d11.dll     -o dxvk/win32/d3d11.dll
	curl https://haagch.frickel.club/files/dxvk/latest/32/bin/setup_dxvk.sh -o dxvk/win32/setup_dxvk.sh
	echo "call setup_dxvk64"
	bash dxvk/win64/setup_dxvk.sh
	bash dxvk/win32/setup_dxvk.sh
fi

#############################################################
# update game files
#############################################################
# use warframe exe to update game files
# use if launcher fails to do so
if [ "$do_update" = true ] ; then
	echo "updating Warframe files"
	## download most recent msi file from the official website
	#wget "http://content.warframe.com/dl/Warframe.msi" -O "$MSI"
	## use warframe executable to update the game files
	#$WINECMD "${WARFRAME}" -silent -log:/Preprocessing.log -dx10:1 -dx11:0 -threadedworker:1 -cluster:public -language:en -applet:/EE/Types/Framework/ContentUpdate

	EXEPREFIX="${warframe_exe_base}"
	if [ ! -d "${EXEPREFIX}" ]; then
		mkdir -p "${EXEPREFIX}"
	fi
	# change directory into Downloaded dir
	cd "${EXEPREFIX}"

	#keep wget as a backup in case curl fails
	#wget -qN http://origin.warframe.com/index.txt.lzma
	curl -A Mozilla/5.0 -s http://origin.warframe.com/index.txt.lzma -o index.txt.lzma
	unlzma -f index.txt.lzma


	echo "*********************"
	echo "Checking for updates."
	echo "*********************"

	#remove old downloaded archives
	find "$EXEPREFIX" -name '*.lzma' -exec rm {} \;

	#create list of all files to download
	rm -f updates.txt
	touch updates.txt
	while read -r line; do
		# get the raw filename with md5sum and lzma extension
		RAW_FILENAME=$(echo $line | awk -F, '{print $1}')
		# path to local file currently tested
		LOCAL_PATH="$EXEPREFIX${RAW_FILENAME:0:-38}"

		# selectively add possible updates
		case "$RAW_FILENAME" in
		*Warframe* | *Launcher*)
			#check if local_index.txt exists
			if [ -f "local_index.txt" ]; then
				#if local index exists, check if new entry is in it
				if grep -q "$RAW_FILENAME" "local_index.txt"; then
					#if it's in the list, check if the file exists already
					if [ ! -f "$LOCAL_PATH" ]; then
						# if file doesnt exist, add it to download list
						echo "$line" >> updates.txt
					fi
				else
					#if new md5sum isn't in local index list, add it to download list
					echo "$line" >> updates.txt
				fi
			else
				#if no md5sum list exists, download all files and log md5sums
				echo "$line" >> updates.txt
			fi
			;;
		*) # match all files
			#check if local_index.txt exists
			if [ "$full_update" = true ]; then
				if [ -f "local_index.txt" ]; then
					#if local index exists, check if new entry is in it
					if grep -q "$RAW_FILENAME" "local_index.txt"; then
						#if it's in the list, check if the file exists already
						if [ ! -f "$LOCAL_PATH" ]; then
							# if file doesnt exist, add it to download list
							echo "$line" >> updates.txt
						fi
					else
						#if new md5sum isn't in local index list, add it to download list
						echo "$line" >> updates.txt
					fi
				else
					#if no md5sum list exists, download all files and log md5sums
					echo "$line" >> updates.txt
				fi
			fi
			;;
		esac
	done < index.txt

	# sum up total size of updates
	TOTAL_SIZE=0
	while read -r line; do
		# get the remote size of the lzma file when downloading
		REMOTE_SIZE=$(echo $line | awk -F, '{print $2}' | sed 's/\r//')
		(( TOTAL_SIZE+=$REMOTE_SIZE ))
	done < updates.txt

	echo "*********************"
	echo "Downloading updates."
	echo "*********************"

	#currently downloaded size
	CURRENT_SIZE=0
	PERCENT=0
	while read -r line; do
		#get the raw filename with md5sum and lzma extension
		RAW_FILENAME=$(echo $line | awk -F, '{print $1}')
		#get the remote size of the lzma file when downloading
		REMOTE_SIZE=$(echo $line | awk -F, '{print $2}' | sed 's/\r//')
		#get the md5 sum from the current line
		MD5SUM=${RAW_FILENAME: -37:-5}
		#convert it to lower case
		MD5SUM=${MD5SUM,,}
		#path to local file currently tested
		LOCAL_FILENAME="${RAW_FILENAME:0:-38}"
		LOCAL_PATH="$EXEPREFIX${LOCAL_FILENAME}"
		#URL where to download the latest file
		DOWNLOAD_URL="http://content.warframe.com$RAW_FILENAME"
		#path to local file to be downloaded
		LZMA_PATH="$EXEPREFIX${RAW_FILENAME}"
		#path to downloaded and extracted file
		EXTRACTED_PATH="$EXEPREFIX${RAW_FILENAME:0:-5}"

		#variable to specify whether to download current file or not
		do_update=true

		if [ -f "$LOCAL_PATH" ]; then
			#local file exists

			#check md5sum of local file
			OLDMD5SUM=$(md5sum "$LOCAL_PATH" | awk '{print $1}')

			if [ "$OLDMD5SUM" = "$MD5SUM" ]; then
				#nothing to do
				do_update=false
			else
				#md5sum mismatch, download new file
				do_update=true
			fi
		else
			# local file does not exist
			do_update=true
		fi

		if [ -f local_index.txt ]; then
			#remove old local_index entry
			sed -i "\#${LOCAL_FILENAME}.*#,+1 d" local_index.txt

			#also remove blank lines
			sed -i '/^\s*$/d' local_index.txt
		fi

		#do download
		if [ "$do_update" = true ]; then
			#show progress percentage for each downloading file
			echo -ne "$PERCENT% ($CURRENT_SIZE/$TOTAL_SIZE) Downloading ${REMOTE_SIZE} ${RAW_FILENAME}                                   " "\r";

			mkdir -p "$(dirname "${LOCAL_PATH}")"
			#download file and replace old file
			#keep wget as a backup in case curl fails
			#wget -x -O "$EXEPREFIX$line" http://content.warframe.com$line
			curl -A Mozilla/5.0 $DOWNLOAD_URL | unlzma - > "$LOCAL_PATH"
		fi

		#update local index
		echo "$line" | sed 's/\r//' >> local_index.txt

		#update progress percentage
		(( CURRENT_SIZE+=$REMOTE_SIZE ))
		PERCENT=$(( ${CURRENT_SIZE}*100/${TOTAL_SIZE} ))
	done < updates.txt
	#print finished message
	echo "$PERCENT% ($CURRENT_SIZE/$TOTAL_SIZE) Finished downloads"

	rm updates.txt
	rm index.txt

	# run warframe internal updater
	$WINECMD "$WARFRAME" -silent -log:/Preprocessing.log -dx10:1 -dx11:1 -threadedworker:1 -cluster:public -language:en -applet:/EE/Types/Framework/ContentUpdate
fi
#############################################################
# cache optimization
#############################################################
if [ "$do_cache" = true ] ; then
	echo "Doing cache optimization"
	$WINECMD "$WARFRAME"  -silent -log:/Preprocessing.log -dx10:1 -dx11:1 -threadedworker:1 -cluster:public -language:en -applet:/EE/Types/Framework/CacheDefraggerAsync /Tools/CachePlan.txt
fi

#############################################################
# actually start the game
#############################################################
if [ "$start_game" = true ] ; then
	if [ "$verbose" = true ] ; then
		export WINEDEBUG=""
	else
		export WINEDEBUG=-all
	fi
	# launcher
	#$WINECMD "${LAUNCHER}"
	# start MSI file instead of launcher, because launcher.exe can't replace itself under wine and loops forever
	#$WINECMD msiexec /i "${MSI}"

    echo "*********************"
    echo "Launching Warframe."
    echo "*********************"

    $WINECMD "$WARFRAME" -log:/Preprocessing.log -dx10:1 -dx11:1 -threadedworker:1 -cluster:public -language:en -fullscreen:0
fi

