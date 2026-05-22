# Run SquadUp against deployed AWS API (ECS + ALB + Cognito).
# From: mobile-frontend/squadup/
# Prerequisite: register + confirm user via API or app signup first.

param(
  [string]$Device = "",
  [string]$ApiBaseUrl = "http://squadup-alb-363579702.us-east-1.elb.amazonaws.com"
)

$defines = @(
  "API_BASE_URL=$ApiBaseUrl",
  "USE_API=true",
  "USE_DEV_AUTH=false"
)

$args = @("run")
if ($Device) { $args += "-d", $Device }
foreach ($d in $defines) { $args += "--dart-define=$d" }

Write-Host "flutter $($args -join ' ')"
& flutter @args
