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

resource "aws_security_group" "furpetto-sg" {
  name = "dev-sg"
  description = "dev-security-group"
  vpc_id = aws_vpc.furpetto-vpc.id

  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Lambda Execution Role
data "aws_iam_policy_document" "AWSLambdaTrustPolicy" {
  statement {
    actions    = ["sts:AssumeRole"]
    effect     = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "furpetto_function_role" {
  name               = "furpetto_function_role"
  assume_role_policy = "${data.aws_iam_policy_document.AWSLambdaTrustPolicy.json}"
}

resource "aws_iam_role_policy_attachment" "furpetto_lambda_policy" {
  role       = "${aws_iam_role.furpetto_function_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda Layers
resource "aws_lambda_layer_version" "lambda_deps_layer" {
  layer_name          = "shared_deps"

  filename            = data.archive_file.deps_layer_code_zip.output_path
  source_code_hash    = data.archive_file.deps_layer_code_zip.output_base64sha256
  
  compatible_runtimes = [ "nodejs20.x" ]
}

resource "aws_lambda_layer_version" "lambda_utils_layer" {
  layer_name          = "shared_utils"

  filename            = data.archive_file.utils_layer_code_zip.output_path
  source_code_hash    = data.archive_file.utils_layer_code_zip.output_base64sha256
  
  compatible_runtimes = [ "nodejs20.x" ]
}

resource "aws_lambda_layer_version" "lambda_services_layer" {
  layer_name          = "shared_utils"

  filename            = data.archive_file.services_layer_code_zip.output_path
  source_code_hash    = data.archive_file.services_layer_code_zip.output_base64sha256
  
  compatible_runtimes = [ "nodejs20.x" ]
}

data "archive_file" "deps_layer_code_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../dist/layers/deps/"
  output_path = "${path.module}/../dist/deps.zip"
}

data "archive_file" "utils_layer_code_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../dist/layers/utils/"
  output_path = "${path.module}/../dist/utils.zip"
}

data "archive_file" "services_layer_code_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../dist/layers/services/"
  output_path = "${path.module}/../dist/services.zip"
}

# Lambda Functions
resource "aws_lambda_function" "get_demo_lambda" {
  function_name    = "get-demo"
  runtime          = "nodejs20.x"
  handler          = "index.handler"

  role             = aws_iam_role.furpetto_function_role.arn

  filename         = data.archive_file.get_demo_zip.output_path
  source_code_hash = data.archive_file.get_demo_zip.output_base64sha256

  layers = [
    aws_lambda_layer_version.lambda_deps_layer.arn,
    aws_lambda_layer_version.lambda_utils_layer.arn,
    aws_lambda_layer_version.lambda_services_layer.arn
  ]
}

data "archive_file" "get_demo_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../dist/handlers/get-demo/"
  output_path = "${path.module}/../dist/get-demo.zip"
}
