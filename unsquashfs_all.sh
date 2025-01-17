#!/bin/bash
# Script to attempt to extract files from a SquashFS image using all of the available unsquashfs utilities in FMK until one is successful.
#
# Craig Heffner
# 27 August 2011

IMG="$1"
DIR="$2"

ROOT="./src"
# should order in ascending version,
# since newer versions may be able to extact older
# and we want *first* supporting version (some exceptions apply)
SUBDIRS="\
squashfs-tools/squashfs-2.1-r2 \
squashfs-tools/squashfs-3.0 \
squashfs-tools/squashfs-3.0-lzma-damn-small-variant \
squashfs-tools/squashfs-2.0-nb4 \
squashfs-tools/squashfs-2.2-r2-7z \
squashfs-tools/squashfs-3.0-e2100 \
squashfs-tools/squashfs-3.2-r2 \
squashfs-tools/squashfs-3.2-r2-lzma \
squashfs-tools/squashfs-3.2-r2-lzma/squashfs3.2-r2/squashfs-tools \
squashfs-tools/squashfs-3.2-r2-hg612-lzma \
squashfs-tools/squashfs-3.2-r2-wnr1000 \
squashfs-tools/squashfs-3.2-r2-rtn12 \
squashfs-tools/squashfs-3.3 \
squashfs-tools/squashfs-3.3-lzma/squashfs3.3/squashfs-tools \
squashfs-tools/squashfs-3.3-grml-lzma/squashfs3.3/squashfs-tools \
squashfs-tools/squashfs-3.4-cisco \
squashfs-tools/squashfs-3.4-nb4 \
squashfs-tools/squashfs-4.2-official \
squashfs-tools/squashfs-4.2 \
squashfs-tools/squashfs-4.0-lzma \
squashfs-tools/squashfs-4.0-realtek \
squashfs-tools/squashfs-hg55x-bin"
TIMEOUT="60"
MKFS=""

function wait_for_complete()
{
	I=0
	PNAME="$1"

	while [ $I -lt $TIMEOUT ]
	do
		sleep 1

		if [ "$(pgrep $PNAME)" == "" ]
		then
			break
		fi

		((I=$I+1))
	done

	if [ "$I" == "$TIMEOUT" ]
	then
		kill -9 $(pgrep $PNAME) 2>/dev/null
	fi
}

if [ "$IMG" == "" ] || [ "$IMG" == "-h" ]
then
	echo "Usage: $0 <squashfs image> [output directory]"
	exit 1
fi

if [ "$DIR" == "" ]
then
	BDIR="./squashfs-root"
	DIR="$BDIR"
	I=1

	while [ -e "$DIR" ]
	do
		DIR="$BDIR-$I"
		((I=$I+1))
	done
fi

IMG=$(readlink -f "$IMG")
DIR=$(readlink -f "$DIR")

# Make sure we're operating out of the FMK directory
cd $(dirname $(readlink -f "$0"))

MAJOR=$(./src/binwalk-2.1.1/src/scripts/binwalk -l 1024 "$IMG" | head -4 | tail -1 | sed -e 's/.*version //' | cut -d'.' -f1)

echo -e "Attempting to extract SquashFS $MAJOR.X file system...\n"

for SUBDIR in $SUBDIRS
do
	if [ "$(echo $SUBDIR | grep "$MAJOR\.")" == "" ]
	then
		echo "Skipping $SUBDIR (wrong version)..."
		continue
	fi

	unsquashfs="$ROOT/$SUBDIR/unsquashfs"
	mksquashfs="$ROOT/$SUBDIR/mksquashfs"

	if [ -e $unsquashfs-lzma ]; then
		echo -ne "\nTrying $unsquashfs-lzma... "

		$unsquashfs-lzma -dest "$DIR" "$IMG" 2>/dev/null &
		#sleep $TIMEOUT && kill $! 1>&2 >/dev/null
		wait_for_complete $unsquashfs-lzma

		if [ -d "$DIR" ]
                then
			if [ "$(ls "$DIR")" != "" ]
			then
				# Most systems will have busybox - make sure it's a non-zero file size
				if [ -e "$DIR/bin/sh" ]
				then
					if [ "$(wc -c "$DIR/bin/sh" | cut -d' ' -f1)" != "0" ]
					then
						MKFS="$mksquashfs-lzma"
					fi
				else
		MKFS="$mksquashfs-lzma"
				fi
			fi

			if [ "$MKFS" == "" ]
			then
				rm -rf "$DIR"
			fi
                fi
	fi
	if [ "$MKFS" == "" ] && [ -e $unsquashfs ]; then
		echo -ne "\nTrying $unsquashfs... "

		$unsquashfs -dest "$DIR" "$IMG" 2>/dev/null &
		#sleep $TIMEOUT && kill $! 1>&2 >/dev/null
		wait_for_complete $unsquashfs

		if [ -d "$DIR" ]
		then
			if [ "$(ls "$DIR")" != "" ]
			then
				# Most systems will have busybox - make sure it's a non-zero file size
				if [ -e "$DIR/bin/sh" ]
				then
					if [ "$(wc -c "$DIR/bin/sh" | cut -d' ' -f1)" != "0" ]
					then
						MKFS="$mksquashfs"
					fi
				else
					MKFS="$mksquashfs"
				fi
			fi

			if [ "$MKFS" == "" ]
			then
				rm -rf "$DIR"
			fi
		fi
	fi

	if [ "$MKFS" != "" ]
	then
		echo "File system sucessfully extracted!"
		echo "MKFS=\"$MKFS\""
		exit 0
	fi
done

echo "File extraction failed!"
exit 1
