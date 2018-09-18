#/bin/bash
# $1: first directory
for file in $(ls $1); do
echo "$file $(cat $1/$file | wc -l) v.s. $(cat $2/$file | wc -l)"
done
