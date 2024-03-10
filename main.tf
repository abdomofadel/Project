# This is my Defined AWS VPC and its Services
#
# This is my Provider
provider "aws" {
  region = "eu-north-1"
}
# Creating New VPC in eu-north-1 region will give me three availabilty zones by default
resource "aws_vpc" "new_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "NewVPC"
  }
}

/* reterive information from my AWS after created to check availabilty zones health 
for ensuring that resources are distributed across availability zones
 that are operational and accessible for new resource deployments.
*/
data "aws_availability_zones" "available" {
  state = "available"
}

# creating my public subnet and assigned it to my VPC and availability zone.
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.new_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-north-1a"  
  map_public_ip_on_launch = true    #This will make any instance to automatically assigned with Public IP.
  tags = {
    Name = "PublicSubnet"
  }
}

# creating my private subnet and assigned it to my VPC and availability zone.

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.new_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-north-1a"  
  map_public_ip_on_launch = false

  tags = {
    Name = "PrivateSubnet"
  }
}

# Creating secondy private subnet in different AZ to ensuring high availability of my DB
resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.new_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "eu-north-1b"  
  map_public_ip_on_launch = false

  tags = {
    Name = "PrivateSubnet2"
  }
}



# Creating Internet gateway to have ability to access the internet
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.new_vpc.id
  tags = {
    Name = "NewVPC_IGW"
  }
}

# Creating Elastic IP to enable Resources in private subnet to access the internet
resource "aws_eip" "nat_eip" {
  domain = "vpc"
   tags = {
    Name = "NATEIP"
  }
}

# Creating Nat gateway for instances in private subnet and assign Elastic IP for it.
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id
  tags = {
    Name = "NewVPC_NAT_GW"
  }
}

# Creating public route table and connect it to my internet gateway.

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.new_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "PublicRouteTable"
  }
}

# Creating link between my public route table and my public subnet.

resource "aws_route_table_association" "public_route_table_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}


# Creating my route table for private instances and connect it to Nat gateway.

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.new_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }
  tags = {
    Name = "PrivateRouteTable"
  }
}

# Creating link between my Private route table and private subnet.

resource "aws_route_table_association" "private_route_table_assoc" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}


# Creating Security Groups to control the traffic of my instances.

resource "aws_security_group" "allow_web" {
  vpc_id = aws_vpc.new_vpc.id

  ingress {
    description = "SSH"                 #Allow Access by SSH protocol to the instances
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"                #Allow access to the web_pages of the instances
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"               #Allow acces to the secure web_pages of the instances
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {                             #Allow instances to go out with all ports
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

#Creating my back end instances and assign the right AMI and placed in public subnet.

resource "aws_instance" "backend_instance" {
  ami           = "ami-00381a880aa48c6c6" 
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  security_groups = [aws_security_group.allow_web.name]   #Assigned security group to it
  key_name      = aws_key_pair.deployer.key_name          #SSH key that I created on my Lap. 

  tags = {
    Name = "BackendInstance"
  }
}

/*Creating my back end instances and assign the right AMI and placed in public subnet
assigned security group to it & give it SSH key that I created on my Lap. 
*/

resource "aws_instance" "frontend_instance" {
  ami           = "ami-00381a880aa48c6c6" 
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  security_groups = [aws_security_group.allow_web.name]    #Assigned security group to it
  key_name      = aws_key_pair.deployer.key_name           #SSH key that I created on my Lap.

  tags = {
    Name = "FrontendInstance"
  }
}



# RDS MySQL Database Instance
resource "aws_db_instance" "db-instance" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t2.micro"
  identifier           = "db-instance"   # This names the RDS instance itself
  db_name              = "Main_DB"       # This specifies the initial DB name for MySQL
  username             = "admin"         
  password             = "Mof60902#nn"    # This is my entered password
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot  = true
  publicly_accessible  = false
  db_subnet_group_name = aws_db_subnet_group.my_db_subnet_group.name

  vpc_security_group_ids = [aws_security_group.mydb_sg.id]

  tags = {
    Name = "MyDBInstance"
  }
}


# DB Subnet Group for the RDS
resource "aws_db_subnet_group" "my_db_subnet_group" {
  name       = "mydbsubnetgroup"
  subnet_ids = [aws_subnet.private_subnet.id, aws_subnet.private_subnet_2.id] # Updated to include both subnets

  tags = {
    Name = "MyDBSubnetGroup"
  }
}


# Security Group for the RDS instance
resource "aws_security_group" "mydb_sg" {
  name        = "mydb-sg"
  description = "Allow internal access to MySQL DB"
  vpc_id      = aws_vpc.new_vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Adjust CIDR as needed for your network
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mydb-security-group"
  }
}


# Uploading my Key after generating it on my OS to AWS to be used as my SSH Key
resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file("/home/mofa88/.ssh/id_rsa.pub")
}


