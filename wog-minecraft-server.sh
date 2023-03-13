#!/bin/bash

wogservername="wog-minecraft-server"

token=''
pathToToken=''

rootPassword=''
defaultRootPassword='DefaultLinodeServerPasswordRoot'


check_default_password () {
  if [ "$rootPassword" = '' ]
  then
    printf "
Root password not set!
It will be defaulted to '$defaultRootPassword'!
It is HIGHLY recommended you set the password using the -p flag!\n\n"
    rootPassword=$defaultRootPassword
  fi
}

wog_minecraft_server_POST () {
  cat <<EOF
  {
    "image": "linode/debian11",
    "region": "eu-central",
    "type": "g6-standard-6",
    "label": "$wogservername",
    "tags": [],
    "root_pass": "$rootPassword",
    "authorized_users": [
        "WorldOfGlory"
    ],
    "booted": true,
    "backups_enabled": false,
    "private_ip": false,
    "stackscript_id": 1139518,
    "stackscript_data": {}
  }
EOF
}

command_status () {
  printf "Current up servers:\n
  $(curl -sH "Authorization: Bearer $token" \
    https://api.linode.com/v4/linode/instances | jq '.data[].label')\n"
}

command_up () {
  check_default_password

  curl -sH "Content-Type: application/json" \
    -H "Authorization: Bearer $token" \
    -X POST -d "$(wog_minecraft_server_POST)" https://api.linode.com/v4/linode/instances

  printf "\n\nServer Booting Up!\n"
}

command_down () {
  linode_minecraft_id=$(curl -sH "Authorization: Bearer $token" \
    https://api.linode.com/v4/linode/instances | \
    jq --arg key $wogservername '.data[] | select(.label==$key) | .id')
  
  echo $linode_minecraft_id

  curl -H "Authorization: Bearer $token" \
    -X DELETE \
    https://api.linode.com/v4/linode/instances/$linode_minecraft_id
}

print_usage() {
  printf "Usage:
    wog-minecraft-server <flags> up|down\n
    -t <token> Your Linode API Token\n
    -h Help\n
    -f <file> Path to file with Linode API Token (dont use with -t)\n
    -p <string> Set root password (default: $defaultRootPassword)\n
    "

}

while getopts 'ht:f:p_' flag; do
  case "${flag}" in
    h) 
       print_usage
       exit 1 ;;
    p) 
       rootPassword="${OPTARG}" ;;
    f) 
       pathToToken="${OPTARG}"
       pathToToken=$(readlink -f $pathToToken)
       token=$(cat $pathToToken) ;;
    t) 
       token="${OPTARG}" ;;
    *) 
       print_usage
       exit 1 ;;
  esac
done
shift $((OPTIND - 1))

if [ "$token" = '' ]
then
  printf "Token required!\n\n"
  print_usage
  exit 1
fi

if [ "$1" = 'status' ]
then
  command_status
elif [ "$1" = 'up' ]
then
  command_up
elif [ "$1" = 'down' ]
then
  command_down
else
  printf "Invalid command!\n\n"
  print_usage
  exit 1
fi


