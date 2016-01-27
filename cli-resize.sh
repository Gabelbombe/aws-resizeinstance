#!/usr/local/bin/bash
## cli-resize.sh engradepro demo app

ENV='non'

APPLICATION="${1}"  #engradepro
ENVIRONMENT="${2}"  #qastg
FUNCTION="${3}"     #app

instances="$(aws ec2 describe-instances       \
--region us-east-1                            \
--profile $ENV                                \
--filters                                     \
  "Name=tag:Application,Values=$APPLICATION"  \
  "Name=tag:Environment,Values=$ENVIRONMENT"  \
  "Name=tag:Function,Values=$FUNCTION"        \
--query 'Reservations[].Instances[].[PrivateIpAddress,InstanceId,Tags[?Key==`Name`].Value[]]' \
--output text | sed '$!N;s/\n/ /')"

echo -e "\nInstances found:"
echo $instances |egrep -o '\S+\s+\S+\s+\S+'

read -r -p "Continue? [y/N] " response
case $response in
    [yY][eE][sS]|[yY])
        echo ''
        ;;
    *)
        exit 1
        ;;
esac

for line in "$(echo $instances |awk '{print % 3')" ; do
  echo $line
done
