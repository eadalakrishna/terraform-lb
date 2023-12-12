resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "tfvpc"
  }
}
resource "aws_key_pair" "key-pair" {
  key_name = "key-pair"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCDyAr2nCgBW4UvcCspd7vQxj9XxEP4giCPC5ZaMPLs0+kmiXQtJcBoivdtWxAV1C0OO4SwSlnIbbXTOLKTLqXl5CFv0vb3CzvpfpvuJUC1E29lP9VDlsmRWtqLomhlO2VH32c4rQ1xpoLkGiuxB48V3lxk6PFPxOjAU2qOSa6fDilEH/YlIYkjy0Bdk5nqhSq4QiyFWtFjUtHD0Ea/YMXVD5bssJrN+686fV5HOqdOvvi1nMl4zOgpiBRFZhDj6YsxzMw8zjC7AO6XlFcRq9aOzw5fnyUWieRW6C2doqsoyaHDFbWcXOcAkWWQmM8tT7LTurGSfFL16BG9w56tRw1F imported-openssh-key"
}
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "myigw"
  }
}
resource "aws_route_table" "route1" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
tags = {
    Name = "route1"
  }
}
resource "aws_subnet" "sub1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.14.0/24"
  availability_zone ="us-east-1a" 
  map_public_ip_on_launch = true
  tags = {
    Name = "subtf1"
  }
}
resource "aws_subnet" "sub2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.40.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "subtf2"
  }
}
resource "aws_subnet" "sub3" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.50.0/24"
  availability_zone = "us-east-1c"
  tags = {
    Name = "subtf3"
  }
}
# routetable association
resource "aws_route_table_association" "rt1" {
  count = 2
  subnet_id      = element([aws_subnet.sub1.id, aws_subnet.sub2.id], count.index)
  route_table_id = aws_route_table.route1.id
}
# security group
resource "aws_security_group" "mysg" {
  name        = "allow_tls" 
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mysg"
  }
}
resource "aws_instance" "myinstance" { 
    count = 2
    ami = "ami-0fa1ca9559f1892ec"
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.mysg.id]
    subnet_id = element([aws_subnet.sub1.id, aws_subnet.sub2.id], count.index)
    key_name = aws_key_pair.key-pair.id
    user_data = "${file("nginx.sh")}"
    tags = {
    Name = "myinstance"
  }
}

resource "aws_lb" "test" {
  name               = "tf-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.mysg.id]
  subnets            = [aws_subnet.sub1.id, aws_subnet.sub2.id, aws_subnet.sub3.id]

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "mytg" {
  name        = "tf-lb"
  target_type = "instance"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
   
}
# targetgroup instaces attachment
resource "aws_lb_target_group_attachment" "test" {
  count = 2  
  target_group_arn = aws_lb_target_group.mytg.arn
  target_id        = aws_instance.myinstance[count.index].id
  port             = 80
}

resource "aws_lb_listener" "lb-tf" {
  load_balancer_arn = aws_lb.test.arn
  port              = "80"
  protocol          = "HTTP"
  

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mytg.arn
  }
}

