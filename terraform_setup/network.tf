variable "az_count" {
  # For both a private and a public subnets, this number needs
  # to be <=128 (65536/(256*2)=128), otherwise the subnet
  # `cidr_block` will be out of range.
  default = "2"
}

# Fetch AZs in the current region
data "aws_availability_zones" "available" {}

# Several options are provided for a user-defined VPC:
# (1) VPC with a single public subnet
# (2) VPC with public and private subnets
# (3) More complicated cases
# https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Scenarios.html
#
# To hold RDS instance in user-defined VPC we need
# at least two subnets, each in a separate availability zone.
# https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_SettingUp.html#CHAP_SettingUp.Requirements
# https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_VPC.html
#
# For chosen (2) it will use private subnet we needs to use NAT gateway
# (`aws_nat_gateway` Terraform resource), with the charging rate
# $400/year plus data.


# VPC in which containers will be networked. It has two public subnets.
# We distribute the subnets across the first two available subnets
# for the region, for high availability.
resource "aws_vpc" "main" {
  # Private IPv4 address ranges by RFC 1918.
  # Netmask can be `/16` or smaller. The largest chosen range includes:
  # - 10.0.0.0/8
  # - 172.16.0.0/12
  # - 192.168.0.0/16
  # https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Subnets.html#VPC_Sizing
  # https://en.wikipedia.org/wiki/Private_network#Private_IPv4_address_spaces
  cidr_block       = "10.0.0.0/16" # 65536 available addresses

  assign_generated_ipv6_cidr_block = false
  enable_dns_support = true
  enable_dns_hostnames = true

  # Decide whether instances launched into your VPC are run on shared or
  # dedicated hardware. Choose "default" or "dedicated". Dedicated
  # tenancy incurs additional costs.
  # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/dedicated-instance.html
  instance_tenancy = "default"

  tags = {
    Name = "circleci-demo-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = "${aws_vpc.main.id}"
  map_public_ip_on_launch = true

  # If two AZs:
  # count.index=0: `10.0.0.0/24` - 256 addresses
  # count.index=1: `10.0.1.0/24`
  # https://www.terraform.io/docs/configuration/functions/cidrsubnet.html
  count             = "${var.az_count}"
  cidr_block        = "${cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)}"
  # Therefore, subnets will be each in a separate availability zone.
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
}

# IGW for the public subnet
#
# Setup networking resources for the public subnets. Containers
# in the public subnets have public IP addresses and the routing table
# sends network traffic via the internet gateway.
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.main.id}"
}

# Route the public subnet trafic through the IGW
resource "aws_route" "internet_access" {
  # This is using the main route table associated with this VPC.
  # This is the default one since it has not been changed by
  # `aws_main_route_table_association`.
  # https://www.terraform.io/docs/providers/aws/r/vpc.html#main_route_table_id
  route_table_id         = "${aws_route_table.public.id}"
  gateway_id             = "${aws_internet_gateway.gw.id}"

  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "private" {
  count          = "${var.az_count}"
  subnet_id      = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id = "${aws_route_table.public.id}"
}
