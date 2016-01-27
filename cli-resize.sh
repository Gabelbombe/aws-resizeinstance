#!/usr/local/bin/bash
## Require AWS CLI tools and JQ
## cli-resize.sh engradepro demo app

AWS_ENV='non'
AWS_REG='us-east-1'

APPLICATION="${1}"  #engradepro
ENVIRONMENT="${2}"  #qastg
FUNCTION="${3}"     #app

instances="$(aws ec2 describe-instances       \
--region  $AWS_REG                            \
--profile $AWS_ENV                            \
--filters                                     \
  "Name=tag:Application,Values=$APPLICATION"  \
  "Name=tag:Environment,Values=$ENVIRONMENT"  \
  "Name=tag:Function,Values=$FUNCTION"        \
--query 'Reservations[].Instances[].[PrivateIpAddress,InstanceId,Tags[?Key==`Name`].Value[]]' \
--output text | sed '$!N;s/\n/ /')"


echo -e "\nInstances found:"
echo $INSTANCES |egrep -o '\S+\s+\S+\s+\S+'
echo


read -r -p "Continue? [y/N] " response
case $response in
  [yY][eE][sS]|[yY])  echo '' ;;
  *)                  exit 1  ;;
esac


echo "[info] Getting list of load balancers"
aws --profile AWS_ENV --region AWS_REG elb describe-load-balancers |jq --arg keyName "$(echo $INSTANCES |awk '{print$2}')" '.LoadBalancerDescriptions[] | select(.Instances[].InstanceId | contains($keyName)) | .LoadBalancerName' |sed 's/\"//g' > /tmp/instance.log


echo "[info] Enabling draining on load balancers"
cat /tmp/instance.log | while read ELB; do
  aws elb modify-load-balancer-attributes --load-balancer-name $ELB --load-balancer-attributes "{\"ConnectionDraining\":{\"Enabled\":true,\"Timeout\":300}}"
done


for instanceId in $(aws ec2 describe-instances --region $AWS_REG --profile $AWS_ENV                                                   \
--filters "Name=tag:Application,Values=$APPLICATION" "Name=tag:Environment,Values=$ENVIRONMENT" "Name=tag:Function,Values=$FUNCTION"  \
--query 'Reservations[].Instances[].[InstanceId]' --output text | sed '$!N;s/\n/ /') ; do


  echo "[info] Deregistering Instance ${instanceId} with ELBs"
  cat /tmp/instance.log | while read ELB; do
    aws elb deregister-instances-from-load-balancer --load-balancer-name $ELB --instances $instanceId
  done


  echo "[info] Stopping ${instanceId}"
  aws ec2 stop-instances --instance-ids $instanceId --region $AWS_REG


  while [ "$status" != "stopped" ]; do
    status=( $(aws ec2 describe-instances --region $AWS_REG --instance-ids $instanceId --output text --query 'Reservations[*].Instances[*].State.Name') )
    echo "[info] The instance ID " $instanceId "is stopping now!"
    sleep 5

    if [ "$status" == "stopped" ]; then
      echo "${instanceId} has ${status}" ; break
    fi
  done


  echo "[info] Modifying Instance Size of ${instanceId}"
  aws ec2 modify-instance-attribute --instance-type "{\"Value\": \"t2.micro\"}" --instance-id $instanceId --region $AWS_REG


  echo "[info] Starting Instance ${instanceId}"
  aws ec2 start-instances --instance-ids $instanceId --region $AWS_REG


  echo "[info] Reregistering Instance ${instanceId} with ELBs"
  cat /tmp/instance.log | while read ELB; do
    aws elb register-instances-with-load-balancer --load-balancer-name $ELB --instances $instanceId
  done

done


echo "[info] Disabling draining on load balancers"
cat /tmp/instance.log | while read ELB; do
  aws elb modify-load-balancer-attributes --load-balancer-name $ELB --load-balancer-attributes "{\"ConnectionDraining\":{\"Enabled\":false}}"
done

rm -f /tmp/instance.log

echo -e "\nDone!\n"
