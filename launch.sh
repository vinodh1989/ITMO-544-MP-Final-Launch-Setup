# While running the launch.sh 
# Pass the arguments in the following order : $1 - ami image-id , $2 - count, $3 - instance-type, $4 - security-group-ids, $5 - subnet-id, $6 - key-name, $7 - iam-profile

#Step 1
#clean up script
#./cleanup.sh

#Step 2
#to create to db instance 
#./launch-rds.sh

#Step 3
#declare a variable
mapfile -t instanceARR < <(aws ec2 run-instances --image-id $1 --count $2 --instance-type $3 --key-name $6 --security-group-ids $4 --subnet-id $5 --associate-public-ip-address --iam-instance-profile Name=$7 --user-data file://../ITMO-544-MP2-Environment-Setup/install-webserver.sh --output table | grep InstanceId | sed "s/|//g" | tr -d ' ' | sed "s/InstanceId//g")

echo ${instanceARR[@]}

aws ec2 wait instance-running --instance-ids ${instanceARR[@]}

echo "Instance are running"

#Step 4
#Creating  Load balancer 
LOAD_BALANCER_NAME='ITMO544MP2ELB'

ELBURL=(`aws elb create-load-balancer --load-balancer-name $LOAD_BALANCER_NAME --listeners Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80 --security-groups $4 --subnets $5 --output=text`);
echo $ELBURL
echo -e "\n Finished launching ELB and sleeping 25 seconds"
for i in {0..25}; do echo -ne '.'; sleep 1;done
echo "\n"

#Step 5
#Register instances with created load balacer

aws elb register-instances-with-load-balancer --load-balancer-name $LOAD_BALANCER_NAME --instances ${instanceARR[@]}

#Step 6
#Health Check configuration
aws elb configure-health-check --load-balancer-name $LOAD_BALANCER_NAME --health-check Target=HTTP:80/index.html,Interval=30,UnhealthyThreshold=2,HealthyThreshold=2,Timeout=3

echo -e "\n waiting for an extra 3 minutes before opening elb in browser"
for i in {0..180}; do echo -ne '.'; sleep 1;done
echo "\n"

#Step 7
#Creating launch configuration and auto scaling group
LAUNCH_CONFIGURATION_NAME='ITMO544MP2LC'
AUTO_SCALING_GROUP_NAME='ITMO544MP2ASG'
EMAIL_ID='vsadayam@hawk.iit.edu'

#Create SNS topic for image upload subscriptions
SNS_CLOUD_WATCH_DISPLAYNAME=MP2CloudWatchSubscriptions
SNS_TOPIC_CLOUD_WATCH_ARN=(`aws sns create-topic --name $SNS_CLOUD_WATCH_DISPLAYNAME`)
aws sns set-topic-attributes --topic-arn $SNS_TOPIC_CLOUD_WATCH_ARN --attribute-name DisplayName --attribute-value $SNS_CLOUD_WATCH_DISPLAYNAME
aws sns subscribe --topic-arn $SNS_TOPIC_CLOUD_WATCH_ARN --protocol email --notification-endpoint $EMAIL_ID

aws autoscaling create-launch-configuration --launch-configuration-name $LAUNCH_CONFIGURATION_NAME --image-id $1 --key-name $6 --security-groups $4 --instance-type $3 --user-data file://../ITMO-544-MP2-Environment-Setup/install-webserver.sh --iam-instance-profile $7
aws autoscaling create-auto-scaling-group --auto-scaling-group-name $AUTO_SCALING_GROUP_NAME --launch-configuration-name $LAUNCH_CONFIGURATION_NAME --load-balancer-names $LOAD_BALANCER_NAME --health-check-type ELB --min-size 3 --max-size 6 --desired-capacity 3 --default-cooldown 300 --health-check-grace-period 120 --vpc-zone-identifier $5

#Create auto scaling policy to monitor  when CPU usage is above or equal to 30 percent 
SCALEUPARN=(`aws autoscaling put-scaling-policy --policy-name SCALEUP --auto-scaling-group-name $AUTO_SCALING_GROUP_NAME --scaling-adjustment 1 --adjustment-type ChangeInCapacity`)
aws cloudwatch put-metric-alarm --alarm-name ADDINSTANCE --alarm-description "when CPU usage is above or equal to 30 percent" --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average --period 120 --threshold 30 --comparison-operator GreaterThanOrEqualToThreshold --evaluation-periods 1 --dimensions "Name=AutoScalingGroupName,Value=$AUTO_SCALING_GROUP_NAME" --unit Percent --alarm-actions $SCALEUPARN $SNS_TOPIC_CLOUD_WATCH_ARN

#Create auto scaling policy to monitor when CPU usage is below or equal to 10 percent 
SCALEDOWNEARN=(`aws autoscaling put-scaling-policy --policy-name SCALEDOWN --auto-scaling-group-name $AUTO_SCALING_GROUP_NAME --scaling-adjustment -1 --adjustment-type ChangeInCapacity`)
aws cloudwatch put-metric-alarm --alarm-name REMOVEINSTANCE --alarm-description "when CPU usage is below or equal to 10 percent" --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average --period 120 --threshold 10 --comparison-operator LessThanOrEqualToThreshold  --evaluation-periods 1 --dimensions "Name=AutoScalingGroupName,Value=$AUTO_SCALING_GROUP_NAME" --unit Percent --alarm-actions $SCALEDOWNEARN $SNS_TOPIC_CLOUD_WATCH_ARN

echo "Created LAUNCH CONFIGURATION and AUTO SCALING GROUP"

#step 8
#Create SNS topic for image upload subscriptions
SNS_IMAGE_DISPLAYNAME=MP2ImageSubscriptions
SNS_TOPIC_IMAGE_ARN=(`aws sns create-topic --name $SNS_IMAGE_DISPLAYNAME`)
aws sns set-topic-attributes --topic-arn $SNS_TOPIC_IMAGE_ARN --attribute-name DisplayName --attribute-value $SNS_IMAGE_DISPLAYNAME    

