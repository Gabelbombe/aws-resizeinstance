#!/usr/local/bin/bash
## cli-resize.sh engradepro demo app

ENV='non'

APPLICATION="${1}"  #engradepro
ENVIRONMENT="${2}"  #qastg
FUNCTION="${3}"     #app


runner="$(aws ec2 describe-instances          \
--region us-east-1                            \
--profile $ENV                                \
--filters                                     \
  "Name=tag:Application,Values=$APPLICATION"  \
  "Name=tag:Environment,Values=$ENVIRONMENT"  \
  "Name=tag:Function,Values=$FUNCTION"        \
--query 'Reservations[].Instances[].[PrivateIpAddress,InstanceId,Tags[?Key==`Name`].Value[]]' \
--output text | sed '$!N;s/\n/ /')"

echo $runner |egrep -o '\S+\s+\S+\s+\S+'
