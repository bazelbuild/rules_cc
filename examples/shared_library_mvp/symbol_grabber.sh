#!/bin/bash

output_file=$1
touch $output_file.symbols
shift
for object_file in "$@" ; do
   nm $object_file | grep " T " |  rev | cut -f1 -d" " | rev   >> $output_file.symbols
done

sort -u $output_file.symbols > "$output_file".symbols.tmp
sed 's/$/\;/' $output_file.symbols.tmp > "$output_file".symbols
rm "$output_file".symbols.tmp

echo "VERS_1.1 {" > "$output_file"
echo "global:" >> "$output_file"
cat "$output_file".symbols >> "$output_file"
echo "local:" >> "$output_file"
echo "*;" >> "$output_file"
echo "};" >> "$output_file"

