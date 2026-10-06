# Build the EC2 + RDS records app by hand

This is a learning exercise, not an automated deployment. There are no
Terraform files, startup scripts, or automatic database migrations. Create
the AWS resources in the AWS Console, connect to the server yourself, create
the database table yourself, and start the app from a shell.

The sample app is in `app/app.py`. It provides a small Flask API backed by
PostgreSQL.

## Before you start

You need an AWS account, a local SSH client, and an AWS Region where the
instance types below are available. The steps use `ap-south-1` as an example;
use the same Region for every resource. Create an AWS Budget alert first if
you are unfamiliar with AWS billing. Small instance types do not guarantee a
particular bill or Free Tier eligibility. RDS storage, public IPv4, data
transfer, backups, and regional pricing may add charges.

Do not put your database password in this project, a screenshot, or a
source-control repository. This tutorial uses a temporary shell environment
variable and does not configure a permanent secret manager.

## 1. Create the network in the AWS Console

1. Open **VPC → Your VPCs → Create VPC**. Select **VPC only**, set the name
   `records-vpc`, IPv4 CIDR `10.0.0.0/16`, and create it. Leave DNS resolution
   and DNS hostnames enabled in the VPC details.
2. Open **Subnets → Create subnet**. Select `records-vpc`, choose one
   Availability Zone, and create a public subnet with CIDR `10.0.1.0/24`.
   Choose a second Availability Zone and create another public subnet with
   `10.0.2.0/24`.
3. In those same two Availability Zones, create private subnets with CIDRs
   `10.0.11.0/24` and `10.0.12.0/24`.
4. Open **Internet gateways → Create internet gateway**, name it
   `records-igw`, then attach it to `records-vpc`.
5. Open **Route tables** and create `records-public-rt` in `records-vpc`.
   Add a route for destination `0.0.0.0/0` with target `records-igw`. Associate
   this route table with both public subnets.
6. In **Subnets**, select each public subnet and choose **Actions → Edit
   subnet settings**. Enable **Auto-assign public IPv4 address**. Do not add an
   internet route to the private subnets; the RDS database does not need one.

The EC2 server will use a public subnet to download packages and accept your
SSH connection. RDS will use the two private subnets and will not have a public
address. This design avoids a NAT Gateway.

## 2. Create security groups

Create these groups in **EC2 → Security Groups**, selecting `records-vpc` for
each one:

**`records-app-sg`**

- Inbound TCP `22` (SSH), source **My IP**. This is for your own SSH session.
- Inbound TCP `5000`, source **My IP**. This is for testing the API from your
  current public IP. Do not use `0.0.0.0/0`.
- Leave the default outbound rule allowing all traffic. The server needs
  outbound access to install packages and connect to RDS.

**`records-db-sg`**

- Inbound PostgreSQL TCP `5432`, source **records-app-sg**. Choose the security
  group as the source; do not enter an IP range or use `0.0.0.0/0`.
- Leave the default outbound rule.

The database rule refers to the EC2 security group, not the EC2 public IP.
That keeps database access restricted to instances using `records-app-sg`.
If your public IP changes, update the SSH and API inbound rules to **My IP**.
The API itself has no login and uses HTTP for this exercise, so keep the
port-5000 rule restricted to your own IP and do not use this setup for
sensitive data or production.

## 3. Create a role for EC2 (optional Systems Manager access)

The app does not use AWS APIs or an IAM role. You can SSH to the EC2 instance
with a key pair instead. If you also want to practice Systems Manager:

1. Open **IAM → Roles → Create role**. Select **AWS service → EC2**.
2. Attach the AWS managed policy `AmazonSSMManagedInstanceCore`.
3. Name the role `records-ec2-ssm-role` and create it.
4. When launching EC2, attach this role as its IAM instance profile.

This role is only for Systems Manager. It does not grant permission to read
the database password, and the app does not retrieve secrets from AWS.

## 4. Create the private PostgreSQL database

1. Open **RDS → Databases → Create database**. Choose **Standard create**,
   engine **PostgreSQL**, and a version supported in your Region.
2. Choose the **Free tier** template only if it is offered and appropriate
   for your account; otherwise choose **Dev/Test**. Set DB instance identifier
   `records-db`, master username `records_admin`, and set a strong master
   password. Save the password somewhere private for this exercise.
3. Choose `db.t3.micro` (or a similarly small available class). Set storage to
   the smallest supported size, for example 20 GiB, and leave storage
   autoscaling off for this exercise.
4. Before creating the database, open **RDS → Subnet groups → Create DB subnet
   group**. Name it `records-db-subnets`, select `records-vpc`, and add both
   private subnets from step 1 (one in each Availability Zone). Then, under
   **Connectivity**, select `records-vpc`, choose **Do not connect to an EC2
   compute resource**, and select `records-db-subnets`.
5. Set **Public access** to **No**. Select the existing `records-db-sg` and
   remove any default security group if the wizard added one.
6. Create the database. Wait until its status is **Available**. In its
   **Connectivity & security** details, copy the endpoint and port. The
   endpoint is a hostname, not a URL, and the port should be `5432`.

Do not use the master password for anything else. This small example uses the
master login for simplicity; a real application should use a separate,
least-privilege database user.

## 5. Launch the EC2 server

1. Open **EC2 → Key Pairs → Create key pair**. Choose a key pair name, select
   RSA and `.pem`, then download and keep the file private. Do not commit it
   to the project.
2. Open **EC2 → Instances → Launch instances**. Name it `records-app`.
3. Choose **Amazon Linux 2023** (64-bit x86) and instance type `t3.nano`.
4. Select or create a key pair. Under **Network settings**, choose
   `records-vpc`, one of its public subnets, enable **Auto-assign public IP**,
   and select **records-app-sg**.
5. Under advanced details, attach `records-ec2-ssm-role` if you created the
   optional IAM role. Leave user data empty; nothing should install or start
   automatically.
6. Launch the instance. Wait for **Running** and both status checks to pass.
   Copy its public IPv4 address.

## 6. Copy the app and install it manually

Run these commands in PowerShell from the project directory. Replace the key
path and public IP with your values:

```powershell
$Key = "$HOME\Downloads\records-app.pem"
$Server = "ec2-user@EC2_PUBLIC_IP"
ssh -i $Key $Server
```

Accept the host key prompt when you have verified that you are connecting to
your instance. In the SSH session, install Python and create a directory:

```bash
sudo dnf install -y python3.11 python3.11-pip curl
mkdir -p ~/records-app
exit
```

Back in PowerShell, copy the two app files to the instance:

```powershell
scp -i $Key .\app\app.py "${Server}:records-app/"
scp -i $Key .\app\requirements.txt "${Server}:records-app/"
ssh -i $Key $Server
```

In the SSH session, install the Python dependencies and download the official
RDS CA bundle used to verify the encrypted database connection:

```bash
cd ~/records-app
python3.11 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
sudo curl --fail --show-error --location \
  https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem \
  --output /etc/pki/tls/certs/rds-global-bundle.pem
```

## 7. Set the connection details and create the table yourself

In the same SSH session, set the RDS values. Replace the example endpoint with
the endpoint copied from the RDS console:

```bash
export DB_HOST="records-db.example.ap-south-1.rds.amazonaws.com"
export DB_PORT="5432"
export DB_NAME="postgres"
export DB_USER="records_admin"
read -s -p "RDS master password: " DB_PASSWORD
echo
export DB_PASSWORD
```

The password will not be displayed as you type. It remains in this shell's
environment and is not saved in the source files. If you close the SSH
session, you will need to set these variables again.

Install the PostgreSQL command-line client and connect to the database. When
prompted, enter the same password:

```bash
sudo dnf install -y postgresql15
psql "host=$DB_HOST port=$DB_PORT dbname=$DB_NAME user=$DB_USER sslmode=verify-full sslrootcert=/etc/pki/tls/certs/rds-global-bundle.pem"
```

At the `postgres=>` prompt, create the application table:

```sql
CREATE TABLE records (
    id BIGSERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    content TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
\q
```

The app deliberately does not create or migrate tables. If you want a separate
application database instead of using the default `postgres` database, create
it yourself, then set `DB_NAME` to that database name before creating the
table.

## 8. Start and test the app

From `~/records-app`, with the virtual environment active and the environment
variables still set, run the development server manually:

```bash
python -m flask --app app run --host 0.0.0.0 --port 5000
```

Leave this SSH session open while testing. The server stops when you press
Ctrl+C or close the session. This is intentional: starting on boot and
background service management are left as separate learning topics.

In another PowerShell window, substitute the EC2 public IP:

```powershell
$Api = "http://EC2_PUBLIC_IP:5000"
Invoke-RestMethod -Method Get -Uri "$Api/health"
Invoke-RestMethod -Method Post -Uri "$Api/records" `
  -ContentType "application/json" `
  -Body '{"title":"First record","content":"Saved in RDS"}'
Invoke-RestMethod -Method Get -Uri "$Api/records"
```

The API also supports `GET /records/<id>`, `PUT /records/<id>`, and
`DELETE /records/<id>`. If the connection fails, check that the RDS status is
Available, the EC2 and RDS are in the same VPC, `records-db-sg` allows TCP
5432 from `records-app-sg`, the endpoint and password are correct, and your
current IP is allowed for port 5000.

## Clean up when finished

Stop the app with Ctrl+C. In the AWS Console, delete the RDS database (choose
whether to take a final snapshot), terminate the EC2 instance, then delete the
IAM role, security groups, subnets, route table, internet gateway, and VPC
created for this exercise. Check for retained snapshots and other billable
resources. Also delete the RDS subnet group and, if no longer needed, the EC2
key pair. Do not delete a VPC until its dependent resources have been removed.
