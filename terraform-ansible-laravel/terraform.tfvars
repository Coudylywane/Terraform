database_endpoint       = "bnbcomply.cnxnnjjfpwxu.us-east-2.rds.amazonaws.com"  
database_name           = "bnb_db"          // database name
database_user           = "bnbcomply"        //database username
shared_credentials_file = "~/.aws/credentials"                //Access key and Secret key file location
region                  = "us-east-2"        //sydney region
ami                     = "ami-00c6c849418b7612c" // linux 2 ami
AZ1                     = "us-east-2a"       // avaibility zone
AZ2                     = "us-east-2b"
AZ3                     = "us-east-2c"
PUBLIC_KEY_PATH         = "./mykey-pair.pub" // key name for ec2, make sure it is created before terrafomr apply
PRIV_KEY_PATH           = "./mykey-pair"
instance_type           = "t2.micro" //type pf instance
instance_class          = "db.t2.micro"
