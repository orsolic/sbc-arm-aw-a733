#!/bin/sh
# Linux script for compiling dtso to dtbo
# deb pkg linux-headers\* for correct running kernel must be installed
# 261018 created, again

FILE_IN="$1"
FILE_OUT_TMP=tmp.dts
FILE_OUT="$(dirname "$FILE_IN")/$(basename -s .dtso "$FILE_IN").dtbo"

if [ "$#" -lt 1 ] ; then
	echo "Usage: $0 <input.dtso>"
	exit 1;
fi

cpp -nostdinc \
	-I /lib/modules/$(uname -r)/build/include \
	-I /lib/modules/$(uname -r)/build/arch/arm64/boot/dts/include \
	-undef \
	-x assembler-with-cpp \
	${FILE_IN} ${FILE_OUT_TMP}
dtc -@ -I dts -O dtb -o ${FILE_OUT} ${FILE_OUT_TMP}
rm -rf "$FILE_OUT_TMP"
ls -lh ${FILE_OUT}
