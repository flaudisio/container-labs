service {
  name = "gatus"
  id   = "%AWS_ACCOUNT_ALIAS%-%AWS_REGION%-%HOSTNAME%"
  port = 8080

  checks = [
    {
      tcp      = "127.0.0.1:8080"
      interval = "5s"
      timeout  = "2s"
    },
  ]

  meta = {
    environment = "%ENVIRONMENT%"
    aws_region  = "%AWS_REGION%"
  }

  tags = [
    "cloud-core",
    "gatus",
  ]
}
