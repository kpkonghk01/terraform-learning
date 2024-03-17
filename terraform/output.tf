output "endpoint_my_profile" {
  value = "${aws_api_gateway_deployment.api_dev.invoke_url}/my/profile"
}
