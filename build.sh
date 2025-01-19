#!/bin/sh

MODULE=merlinclash
VERSION=25.01.19
TITLE="Merlin Clash"
DESCRIPTION="Merlin Clash"
HOME_URL=Module_merlinclash.asp
arch_list="mips mipsle arm armng arm64"
CURR_PATH="$( cd "$( dirname "$BASH_SOURCE[0]" )" && pwd )"

do_build() {
	if [ "$VERSION" = "" ]; then
		echo "version not found"
		exit 3
	fi
	echo $VERSION > $MODULE/version
	echo $1 > $MODULE/.arch
	rm -f ${MODULE}.tar.gz
	rm -f $MODULE/.DS_Store
	rm -f $MODULE/*/.DS_Store
	rm -rf $MODULE/bin
	mkdir -p $MODULE/bin
	cp -rf ./bin_arch/$1/clash $MODULE/bin/
	cp -rf ./bin_arch/$1/subconverter $MODULE/bin/
	cp -rf ./bin_arch/$1/client_linux $MODULE/bin/
	tar -zcvf ${MODULE}.tar.gz $MODULE
	md5value=`md5sum ${MODULE}.tar.gz|tr " " "\n"|sed -n 1p`
	cat > ./version <<-EOF
	$VERSION
	$md5value
	EOF
	cat version
	
	DATE=`date +%Y-%m-%d_%H:%M:%S`
	cat > ./config.json.js <<-EOF
	{
	"build_date":"$DATE",
	"description":"$DESCRIPTION",
	"home_url":"$HOME_URL",
	"md5":"$md5value",
	"name":"$MODULE",
	"tar_url": "https://raw.githubusercontent.com/zusterben/plan_c/master/bin/$1/merlinclash.tar.gz", 
	"title":"$TITLE",
	"version":"$VERSION"
	}
	EOF
	cp -rf version ./bin/$1/version
	cp -rf config.json.js ./bin/$1/config.json.js
	cp -rf merlinclash.tar.gz ./bin/$1/merlinclash.tar.gz
	rm -rf $MODULE/bin
	rm -rf $MODULE/version
	rm -rf $MODULE/.arch
}

do_backup(){
	HISTORY_DIR="./history_package/$1"
	# backup latested package after pack
	backup_version=`cat version | sed -n 1p`
	backup_tar_md5=`cat version | sed -n 2p`
	echo backup VERSION $backup_version
	mkdir -p $HISTORY_DIR
	cp ${MODULE}.tar.gz $HISTORY_DIR/${MODULE}_$backup_version.tar.gz
	sed -i "/$backup_version/d" "$HISTORY_DIR"/md5sum.txt
	echo $backup_tar_md5 ${MODULE}_$backup_version.tar.gz >> "$HISTORY_DIR"/md5sum.txt
}

for arch in $arch_list
do
do_build $arch
do_backup $arch
done
rm version config.json.js merlinclash.tar.gz

