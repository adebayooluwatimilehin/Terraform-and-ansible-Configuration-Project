#Create vpc
resource "aws_vpc" "prod_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "prod-vpc"
  }
}

#Create internet gateway
resource "aws_internet_gateway" "prod_gw" {
  vpc_id = aws_vpc.prod_vpc.id

  tags = {
    Name = "prod_gw"
  }
}

#Create route table
resource "aws_route_table" "prod_rt" {
  vpc_id = aws_vpc.prod_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod_gw.id
  }

  tags = {
    Name = "prod_rt"
  }
}

#Create route table association
resource "aws_route_table_association" "prod_rta" {
  count = 3
  subnet_id = aws_instance.web_servers.*.subnet_id[count.index]
  route_table_id = aws_route_table.prod_rt.id
}

#Create subnets for the 3 instances
resource "aws_subnet" "prod_subnet" {
  count = length(var.availability_zones)

  cidr_block = "10.0.${count.index + 1}.0/24"
  vpc_id     = aws_vpc.prod_vpc.id
  availability_zone = var.availability_zones[count.index]
 
  tags = {
    Name = "prod-subnet-${count.index + 1}"
  }
}

#Creates a security group
resource "aws_security_group" "prod_sg" {
  name        = "prod-security-group"
  description = "Allows SSH.HTTP and HTTPS traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

egress  {
   from_port    = 0
   to_port      = 0
   protocol     = "-1"
   cidr_blocks  = ["0.0.0.0/0"] 
  }
  vpc_id = aws_vpc.prod_vpc.id
}


# Create 3 ec2 instance 
resource "aws_instance" "web_servers" {
  count = 3

  key_name = "prod-keypair"
  ami           = "ami-00874d747dde814fa"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.prod_subnet.*.id[count.index]

  vpc_security_group_ids = [aws_security_group.prod_sg.id]
  
  associate_public_ip_address = true

}

#Create an application load balancer
resource "aws_alb" "my-alb" {
  name            = "my-alb-alb"
  internal        = false
  security_groups = [aws_security_group.prod_sg.id]
  subnets         = aws_subnet.prod_subnet.*.id

  tags = {
    Name = "my-alb"
  }
}

#Create a target group
resource "aws_alb_target_group" "alb-tg" {
  name = "als-tg-target-group"
  port = 80
  protocol = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.prod_vpc.id
}

#Create listeners
resource "aws_alb_listener" "alb_listener" {
  load_balancer_arn = aws_alb.my-alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.alb-tg.arn
    type             = "forward"
  }
}

#Attaches the webservers to a target group
resource "aws_alb_target_group_attachment" "target_gp_att" {
  count = 3
  target_group_arn = aws_alb_target_group.alb-tg.arn
  target_id        = aws_instance.web_servers.*.id[count.index]
}

#Creates Route53 zone
resource "aws_route53_zone" "awz" {
  name = var.domain_name
}

#Creates Route53 A record for subdomain
resource "aws_route53_record" "awr" {
  zone_id = aws_route53_zone.awz.zone_id
  name    = var.sub_domain_name
  type    = "A"
  alias {
    name                   = aws_alb.my-alb.dns_name
    zone_id                = aws_alb.my-alb.zone_id
    evaluate_target_health = true
  }
}


#Prints the ip address of the instances
output "instance_ips"{ 
  value = aws_instance.web_servers.*.public_ip 
} 

data "template_file" "host_inventory" { 
  template = <<EOF
Instance IPs:
{{range aws_instance.web_servers -}}
- {{ .public_ip}}
{{- end}}
EOF
}

#Creates host inventory
resource "local_file" "host_inventory" { 
  content = data.template_file.host_inventory.rendered 
  filename = "inventory/host-inventory" 
}