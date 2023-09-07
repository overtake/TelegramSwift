#!/bin/sh

# This script will tell you if there are headers in the source tree
# that have not been installed in $PREFIX

LIST=""

for i in $(find spa/include -name '*.h' | sed s#spa/include/##);
do
	[ -f "$PREFIX/include/spa-0.2/$i" ] || LIST="$i $LIST"
done

for i in $(find src/extensions -name '*.h' | sed s#src/#pipewire/#);
do
	[ -f "$PREFIX/include/pipewire-0.3/$i" ] || LIST="$i $LIST"
done

for i in $(find src/pipewire -name '*.h' -a -not -name '*private.h' | sed s#src/##);
do
	[ -f "$PREFIX/include/pipewire-0.3/$i" ] || LIST="$i $LIST"
done

for i in $LIST;
do
	echo "$i not installed"
done

if [ "$LIST" != "" ];
then
	exit 1
fi

exit 0
