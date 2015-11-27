
#Step 2
#to create mysql RDS db instance
DB_INSTANCE_IDENTIFIER='mp1-vinodh-db'
DB_USERNAME='controller'
DB_PASSWORD='letmein1234'
DB_NAME='customerrecords'
DEFAULT_SUBNET_GROUP_NAME='default-vpc-cc25eaa8'

echo "Creating RDS DB Instances mp1-vinodh-db ...."
aws rds create-db-instance --db-name $DB_NAME --db-instance-identifier $DB_INSTANCE_IDENTIFIER --db-instance-class db.t2.micro --engine MySQL --master-username $DB_USERNAME --master-user-password $DB_PASSWORD --allocated-storage 10 --db-subnet-group-name $DEFAULT_SUBNET_GROUP_NAME --engine-version 5.6.23

#waiting till db instances get created
echo "waiting till db instances to get created for 10 mins "
aws rds wait db-instance-available --db-instance-identifier mp1-vinodh-db
echo "DB Instance mp1-vinodh-db Available Now"

#to create read replica of db instance
echo "Creating RDS Read Replica DB Instances...."
aws rds create-db-instance-read-replica --db-instance-identifier mp1-vinodh-db-read-replica --source-db-instance-identifier $DB_INSTANCE_IDENTIFIER

#waiting till read replica of db instance get created
echo "waiting till read db instances to get created for 10 mins " 
aws rds wait db-instance-available --db-instance-identifier mp1-vinodh-db-read-replica 
echo "DB Instance Read Replica mp1-vinodh-db-read-replica Available Now"