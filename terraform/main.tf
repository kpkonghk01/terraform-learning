resource "aws_vpc" "furpetto-vpc" {
  cidr_block = "172.31.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true

  tags = {
    Name = "dev"
  }
}

resource "aws_subnet" "furpetto-subnet" {
  vpc_id = aws_vpc.furpetto-vpc.id
  cidr_block = "172.31.16.0/20"
  map_public_ip_on_launch = true
  availability_zone = "ap-northeast-1a"

  tags = {
    Name = "dev-public"
  }
}

resource "aws_internet_gateway" "furpetto-igw" {
  vpc_id = aws_vpc.furpetto-vpc.id

  tags = {
    Name = "dev-igw"
  }
}

resource "aws_route_table" "furpetto-public-rt" {
  vpc_id = aws_vpc.furpetto-vpc.id

  tags = {
    Name = "dev-public-rt"
  }
}

resource "aws_route" "default-route" {
  route_table_id = aws_route_table.furpetto-public-rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.furpetto-igw.id
}

resource "aws_route_table_association" "furpetto-public-rt-assoc" {
  subnet_id = aws_subnet.furpetto-subnet.id
  route_table_id = aws_route_table.furpetto-public-rt.id
}
