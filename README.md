# EC2 + RDS records API

A small AWS example that deploys a Flask API on EC2 and stores records in
PostgreSQL on Amazon RDS. Terraform creates a VPC with a public subnet for EC2
and private subnets for RDS. The database security group accepts traffic only
from the EC2 security group; it has no public address.

The API listens on port `5000`. Its security-group ingress rule is omitted
unless `allowed_app_cidr` is set, so the API is not reachable from the internet
by default. Set it to a trusted client IP in CIDR notation (for example,
`203.0.113.10/32`) before deploying if you want to call the API directly.
There is no application-level authentication, so do not expose it to untrusted
clients.

## Prerequisites

- An AWS account and credentials configured for the AWS CLI or another
  supported AWS credential provider.
- Terraform 1.5 or newer.
- An AWS region with at least two Availability Zones and support for
  `t3.nano` EC2 and `db.t3.micro` PostgreSQL RDS instances.

## Configure and deploy

1. Copy `infra/terraform.tfvars.example` to `infra/terraform.tfvars`.
2. Set `aws_region` and choose a strong, unique `db_password` of at least 16
   printable ASCII characters (without spaces, `/`, `@`, `'`, or `"`). To
   enable direct API access, also set `allowed_app_cidr` to your trusted public
   IP with `/32`.
3. From the `infra` directory, run:

   ```powershell
   terraform init
   terraform plan
   terraform apply
   ```

Terraform stores the RDS password in an SSM Parameter Store `SecureString`;
the EC2 instance role can read only that parameter. Terraform state also
contains sensitive infrastructure values, including the password. Keep the
state file and `terraform.tfvars` private, and use a suitably protected remote
state backend for shared or production use.

The EC2 instance uses Amazon Linux 2023 and Systems Manager Session Manager;
the configuration does not open SSH. The instance downloads Python packages
and the RDS CA bundle at first boot, so it needs outbound internet access.
Check EC2 Systems Manager registration and `/var/log/cloud-init-output.log`
if the API is not ready after deployment.

## Use the API

Terraform prints `api_url` and `health_url` after deployment. Once the
instance has finished bootstrapping and your source IP is allowed:

```powershell
Invoke-RestMethod -Method Get -Uri "<health_url>"
Invoke-RestMethod -Method Post -Uri "<api_url>/records" `
  -ContentType "application/json" `
  -Body '{"title":"Example","content":"Stored in PostgreSQL"}'
Invoke-RestMethod -Method Get -Uri "<api_url>/records"
```

Available endpoints:

- `GET /health` — checks database connectivity.
- `GET /records` and `GET /records/<id>` — read records.
- `POST /records` — create a record with a JSON `title` and optional `content`.
- `PUT /records/<id>` — replace a record's title and content.
- `DELETE /records/<id>` — delete a record.

## Costs and cleanup

Instance, database, storage, public IPv4, data transfer, and regional pricing
all affect the bill. The example uses small instance classes, one RDS
Availability Zone, and no NAT Gateway, but the suggested hourly figures are
not guaranteed and may exclude storage or other charges. Review the AWS
pricing page and your account's Free Tier eligibility before applying.

When finished, run `terraform destroy` from `infra`. This development setup
skips a final RDS snapshot, so destroying it permanently removes the database
and its records.
