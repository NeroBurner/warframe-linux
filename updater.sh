#!/bin/bash

EXEPREFIX="$WINEPREFIX/drive_c/Program Files/Warframe/Downloaded/Public"

WINECMD=${WINE-wine}

wget -qN http://origin.warframe.com/index.txt.lzma
unlzma -f index.txt.lzma

echo "*********************"
echo "Checking for updates."
echo "*********************"

find "$EXEPREFIX" -name '*.lzma' -exec rm {} \;

sed -i.bak 's/\.lzma.*/.lzma/' index.txt
if [ -d "$EXEPREFIX" ] && [ ! -f "md5sums.txt" ]; then
    find "$EXEPREFIX" -name '*.*' -type f -exec md5sum {} \; | awk '{print $1}' > md5sums.txt;
fi

echo "*********************"
echo "Downloading updates."
echo "*********************"

PROGRESS=$(wc -l index.txt)
PROGRESS=$((${PROGRESS::-10}/100))
LINECOUNT=0
PERCENT=0

while read line
do
    MD5SUM=${line: -32:-5}
    MD5SUM=${MD5SUM,,}
    if [ -f "md5sums.txt" ]; then
        if `grep -q "$MD5SUM" "md5sums.txt"`; then
            if [ -f "$EXEPREFIX${line::-38}" ]; then
                # if the new line md5 sum is in the current md5 sum list and the file exists, do nothing
                :
            else
                # if the new line md5 sum is in the list, but doesnt exist, download it
                wget -x -O "$EXEPREFIX$line" http://content.warframe.com$line
                find "$EXEPREFIX" -name '*.lzma' -exec unlzma -f {} \;
                mv "$EXEPREFIX${line::-5}" "$EXEPREFIX${line::-38}"

            fi
        else
            #if new md5sum isn't in old md5sum list,check file for old md5sum, remove it from the list, remove blank lines
            if [ -f "$EXEPREFIX${line::-38}" ]; then
                OLDMD5SUM=$(md5sum "$EXEPREFIX${line::-38}" | awk '{print $1}')
                sed -i "/$OLDMD5SUM/,+1 d" md5sums.txt
                sed -i '/^\s*$/d' md5sums.txt
            fi

            wget -x -q -O "$EXEPREFIX$line" http://content.warframe.com$line
            find "$EXEPREFIX" -name '*.lzma' -exec unlzma -f {} \;
            mv "$EXEPREFIX${line::-5}" "$EXEPREFIX${line::-38}"

            #add new md5sum to md5sums list.
            echo "$MD5SUM" >> "md5sums.txt"
        fi
    else
        #if no md5sum list exists, download all files and log md5sums
        #download new file,unlzma it, move it to correct folder
        wget -x -q -O "$EXEPREFIX$line" http://content.warframe.com$line
        find "$EXEPREFIX" -name '*.lzma' -exec unlzma -f {} \;
        mv "$EXEPREFIX${line::-5}" "$EXEPREFIX${line::-38}"

        #add new md5sum to md5sums list.
        echo "$MD5SUM" >> "md5sums.txt"
    fi
    (( LINECOUNT+=1 ))
    if (( LINECOUNT > PROGRESS )) && (( PERCENT < 101 )); then
        (( PERCENT+=1 ))
        echo -ne "$PERCENT% Downloading $EXEPREFIX${line::-38}                                   " "\r";
        LINECOUNT=0
    fi
done < index.txt

# cleanup
rm index.*

if [ "$WINEARCH" = "win64" ]; then
    $WINECMD "$EXEPREFIX/Warframe.x64.exe" -silent -log:/Preprocessing.log -dx10:1 -dx11:1 -threadedworker:1 -cluster:public -language:en -applet:/EE/Types/Framework/ContentUpdate

    echo "*********************"
    echo "Launching Warframe."
    echo "*********************"

    $WINECMD "$EXEPREFIX/Warframe.x64.exe" -log:/Preprocessing.log -dx10:1 -dx11:1 -threadedworker:1 -cluster:public -language:en -fullscreen:0
else
    $WINECMD "$EXEPREFIX/Warframe.exe" -silent -log:/Preprocessing.log -dx10:1 -dx11:1 -threadedworker:1 -cluster:public -language:en -applet:/EE/Types/Framework/ContentUpdate

    echo "*********************"
    echo "Launching Warframe."
    echo "*********************"

    $WINECMD "$EXEPREFIX/Warframe.exe" -log:/Preprocessing.log -dx10:1 -dx11:1 -threadedworker:1 -cluster:public -language:en -fullscreen:0
fi
