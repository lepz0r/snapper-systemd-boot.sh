#!/bin/sh

# Check if this run run as root or not

if [ -z $UID ]
then
UID=$(id -u)
fi

if [ $UID != 0 ]
then
	echo "Error: this script must be run as root"
	exit
fi

# Variables
snapshots_dir="/.snapshots"
config_directory="/etc/snapper-systemd-boot"
config_location="$config_directory/snapper-systemd-boot.sh.conf"

snapshots_subvolume=$(grep snapshot-subvolume-location $config_location | awk '{print $2}')
esp_location=$(grep esp-location $config_location | awk '{print $2}')

# Functions
parse_xml()
{
	snapshot_number=$(basename -a $1)
	snapshot_date=$(xmllint --xpath "string((/snapshot/date))" $1/info.xml)
	snapshot_type_internal=$(xmllint --xpath "string((/snapshot/type))" $1/info.xml)
	snapshot_description=$(xmllint --xpath "string((/snapshot/description))" $1/info.xml)
	if [ "$snapshot_type_internal" = "post" ]
	then
		snapshot_pre_number=$(xmllint --xpath "string((/snapshot/pre_num))" $1/info.xml)
		snapshot_type="$snapshot_type_internal-$snapshot_pre_number"
	else
		snapshot_type="$snapshot_type_internal"
	fi

}

parse_entry()
{
	title="$(grep -E '^title'  $1 | awk '{$1=""; print $0}')"
	version="$(grep -E '^version' $1 | awk '{$1=""; print $0}')"
	machine_id="$(grep -E '^machine-id' $1 | awk '{$1=""; print $0}')"
	linux="$(grep -E '^linux' $1 | awk '{$1=""; print $0}')"
	initrd="$(grep -E '^initrd' $1 | awk '{$1=""; print $0}')"
	efi="$(grep -E '^efi' $1 | awk '{$1=""; print $0}')"
	options="$(grep -E '^options' $1 | awk '{$1=""; print $0}')"
	devicetree="$(grep -E '^devicetree' $1 | awk '{$1=""; print $0}')"
	devicetree_overlay="$(grep -E '^devicetree-overlay' $1 | awk '{$1=""; print $0}')"
}


###################################

rm $esp_location/loader/entries/*.ssb.conf > /dev/null 2>&1 || true

for cur_snapshot_dir in $snapshots_dir/*
do
	parse_xml $cur_snapshot_dir
	for cur_config in $config_directory/entries/*.conf
	do
		output_file=$esp_location/loader/entries/$(basename $cur_config .conf)-snapshot-$snapshot_number.ssb.conf
		parse_entry $cur_config
		for key_number in 0 1 2 3 4 5 6 7 8
		do
			case $key_number in
				0)
					current_key=title
					value="$title snapshot #$snapshot_number $snapshot_description  $snapshot_date ($snapshot_type)"
					;;
				1)
					current_key=version
					value=$version
					;;
				2)
					current_key=machine-id
					value=$machine_id
					;;
				3)
					current_key=linux
					value=$linux
					;;
				4)
					current_key=initrd
					value=$initrd
					;;
				5)
					current_key=efi
					value=$efi
					;;
				6)
					current_key=options
					options_no_rootflag=$(echo $options | sed 's/rootflags=[^ ]*//ig')
					rootflags="$(echo $options | grep -o 'rootflags=[^ ]*')"
					if [ -n "$rootflags" ]
					then
						rootflags="$(echo $options | grep -o 'rootflags=[^ ]*'),subvol=$snapshots_subvolume/$snapshot_number/snapshot"
					else
						rootflags="rootflags=subvol=$snapshots_subvolume/$snapshot_number/snapshot"
					fi
					value="$options_no_rootflag $rootflags"
					;;
				7)
					current_key=devicetree
					value=$devicetree
					;;
				8)
					current_key=devicetree-overlay
					value=$devicetree_overlay
					;;
			esac
			if [ -n "$value" ]
			then
				echo "$current_key $value" >> $output_file
			fi
		done
	done
done

#for cur_snapshot_dir in $snapshots_dir/*
#do
#	parse_xml $cur_snapshot_dir
#	echo "/tmp/-snapshot-$snapshot_number.ssb.conf"
#	#echo "snapshot #$snapshot_number $snapshot_date $snapshot_description ($snapshot_type) "
#	#echo 
#done
