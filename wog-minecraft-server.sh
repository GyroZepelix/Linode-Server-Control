#!/bin/bash

linode_server_name="wog-minecraft-server"

token=''
pathToToken=''
rootPassword=''

defaultRootPassword='DefaultLinodeServerPasswordRoot'

volume_name='WOG-Server'


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
    "label": "$linode_server_name",
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
  status_json=$(curl -sH "Authorization: Bearer $token" \
    https://api.linode.com/v4/linode/instances)

  status_formated=$(echo $status_json | jq -r '.data[] | "\(.id) \(.label)   \(.status)   \(.ipv4)"')
  
  printf "Current up servers:\n$status_formated
  \n"
}

volume_with_name () {
  curl -sH "Authorization: Bearer $token" \
    https://api.linode.com/v4/volumes | jq -r --arg key $volume_name '.data[] | select(.label==$key)'

}

# $1 is id of the linode to attach the volume to
attach_volume () {

  volume_id=$(volume_with_name | jq -r '.id')


  curl -H "Content-Type: application/json" \
    -H "Authorization: Bearer $token" \
    -X POST -d '{
      "linode_id": '$1'
    }' \
    https://api.linode.com/v4/volumes/$volume_id/attach
}


command_up () {
  check_default_password

  post_output=$(curl -sH "Content-Type: application/json" \
    -H "Authorization: Bearer $token" \
    -X POST -d "$(wog_minecraft_server_POST)" \
    https://api.linode.com/v4/linode/instances)

  printf "\n\nServer Booting Up!\n"

  attach_volume $(echo $post_output | jq -r '.id')

  printf "\n\n Connect to the instance with ssh root@$(echo $post_output | jq -r '.ipv4[0]')\n"
}

command_down () {
  linode_minecraft_id=$(curl -sH "Authorization: Bearer $token" \
    https://api.linode.com/v4/linode/instances | \
    jq --arg key $linode_server_name '.data[] | select(.label==$key) | .id')
  
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


