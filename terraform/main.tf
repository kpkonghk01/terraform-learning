resource "aws_vpc" "furpetto_vpc" {
  cidr_block           = "172.31.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dev"
  }
}

resource "aws_subnet" "furpetto_subnet" {
  vpc_id                  = aws_vpc.furpetto_vpc.id
  cidr_block              = "172.31.16.0/20"
  map_public_ip_on_launch = true
  availability_zone       = "ap-northeast-1a"

  tags = {
    Name = "dev-public"
  }
}

resource "aws_internet_gateway" "furpetto_igw" {
  vpc_id = aws_vpc.furpetto_vpc.id

  tags = {
    Name = "dev-igw"
  }
}

resource "aws_route_table" "furpetto_public_rt" {
  vpc_id = aws_vpc.furpetto_vpc.id

  tags = {
    Name = "dev-public-rt"
  }
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.furpetto_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.furpetto_igw.id
}

resource "aws_route_table_association" "furpetto_public_rt_assoc" {
  subnet_id      = aws_subnet.furpetto_subnet.id
  route_table_id = aws_route_table.furpetto_public_rt.id
}

resource "aws_security_group" "furpetto_sg" {
  name        = "dev-sg"
  description = "dev-security-group"
  vpc_id      = aws_vpc.furpetto_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Lambda Execution Role
data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "furpetto_function_role" {
  name               = "furpetto_function_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "furpetto_lambda_policy" {
  role       = aws_iam_role.furpetto_function_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda Layers
resource "aws_lambda_layer_version" "lambda_deps_layer" {
  layer_name = "shared_deps"

  filename         = data.archive_file.deps_layer_code_zip.output_path
  source_code_hash = data.archive_file.deps_layer_code_zip.output_base64sha256

  compatible_runtimes = ["nodejs20.x"]
}

resource "aws_lambda_layer_version" "lambda_modules_layer" {
  layer_name = "shared_modules"

  filename         = data.archive_file.modules_layer_code_zip.output_path
  source_code_hash = data.archive_file.modules_layer_code_zip.output_base64sha256

  compatible_runtimes = ["nodejs20.x"]
}

data "archive_file" "deps_layer_code_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../dist/deps/"
  output_path = "${path.module}/../dist/deps.zip"
}

data "archive_file" "modules_layer_code_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../dist/modules/"
  output_path = "${path.module}/../dist/modules.zip"
}

# Lambda Functions
resource "aws_lambda_function" "get_my_profile_handler" {
  function_name = "get-my-profile"
  runtime       = "nodejs20.x"
  handler       = "index.handler"

  role = aws_iam_role.furpetto_function_role.arn

  filename         = data.archive_file.get_my_profile_archive.output_path
  source_code_hash = data.archive_file.get_my_profile_archive.output_base64sha256

  layers = [
    aws_lambda_layer_version.lambda_deps_layer.arn,
    aws_lambda_layer_version.lambda_modules_layer.arn
  ]
}

resource "aws_lambda_permission" "get_my_profile_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_my_profile_handler.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.furpetto_api.execution_arn}/*"
}

data "archive_file" "get_my_profile_archive" {
  type        = "zip"
  source_dir  = "${path.module}/../dist/handlers/get-my-profile/"
  output_path = "${path.module}/../dist/get-my-profile.zip"
}

# API Gateway
resource "aws_api_gateway_rest_api" "furpetto_api" {
  name        = "furpetto-api"
  description = "Furpetto API"
}

resource "aws_api_gateway_resource" "my_resource" {
  rest_api_id = aws_api_gateway_rest_api.furpetto_api.id
  parent_id   = aws_api_gateway_rest_api.furpetto_api.root_resource_id
  path_part   = "my"
}

resource "aws_api_gateway_resource" "my_profile_resource" {
  rest_api_id = aws_api_gateway_rest_api.furpetto_api.id
  parent_id   = aws_api_gateway_resource.my_resource.id
  path_part   = "profile"
}

resource "aws_api_gateway_method" "get_my_profile_method" {
  rest_api_id   = aws_api_gateway_rest_api.furpetto_api.id
  resource_id   = aws_api_gateway_resource.my_profile_resource.id
  http_method   = "GET"
  authorization = "NONE"
  # How to use Cognito User Pool Authorizer?
  # https://registry.terraform.io/providers/-/aws/5.40.0/docs/resources/api_gateway_method#usage-with-cognito-user-pool-authorizer
  # authorization = "COGNITO_USER_POOLS"
}

resource "aws_api_gateway_integration" "get_my_profile_integration" {
  rest_api_id             = aws_api_gateway_rest_api.furpetto_api.id
  resource_id             = aws_api_gateway_resource.my_profile_resource.id
  http_method             = aws_api_gateway_method.get_my_profile_method.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.get_my_profile_handler.invoke_arn
}

resource "aws_api_gateway_deployment" "api_dev" {
  depends_on        = [aws_api_gateway_integration.get_my_profile_integration]
  rest_api_id       = aws_api_gateway_rest_api.furpetto_api.id
  stage_name        = "api_dev"
  stage_description = "Development Stage"
  description       = "Deployed to Development"
}

# Postgres RDS
# resource "aws_db_instance" "furpetto_db" {
#   allocated_storage      = 20
#   storage_type           = "gp3"
#   engine                 = "postgres"
#   engine_version         = "15.4"
#   instance_class         = "db.t2.micro"
#   db_name                = "furpetto"
#   username               = var.postgresql_username
#   password               = var.postgresql_password
#   parameter_group_name   = "default.postgres15"
#   skip_final_snapshot    = true
#   publicly_accessible    = false
#   vpc_security_group_ids = [aws_security_group.furpetto_sg.id]

#   tags = {
#     Name = "dev-db"
#   }
# }