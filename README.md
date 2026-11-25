# CarePulse — Database Setup Guide

This repository contains the PostgreSQL schema and fictional demonstration data for the CarePulse Hospital Operations Monitoring platform. It is a read-only operational portfolio demo, not a clinical system. No patient-identifying information is included.

## Repository structure

- `01-schema.sql`: Creates departments, appointments and equipment tables, constraints and indexes.
- `02-demo-data.sql`: Inserts six departments, 24 fictional appointment codes and 18 equipment records on a fresh database.

Deploy in this order: **database → query service → dashboard**. Choose only one database hosting option below. PostgreSQL 18 is the target; use the latest supported minor version. Azure SQL Database is a different engine and is not compatible.

## Option 1: IaaS — PostgreSQL on Ubuntu VM

### Step 1: Configure networking

Create an Ubuntu LTS VM in the same virtual network as the backend VM. Allow TCP 22 only from your workstation IP (or a jump host) and TCP 5432 only from the backend private IP. Do not allow 5432 from the entire internet. Give the VM an explicit outbound internet route for package installation. For pgAdmin, use an SSH tunnel rather than exposing the database publicly.

### Step 2: Install PostgreSQL

SSH to the database VM (replace the example public IP):

```bash
ssh azureuser@YOUR_DB_VM_PUBLIC_IP
sudo apt update
sudo apt install -y curl ca-certificates git postgresql-common
sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
sudo apt update
sudo apt install -y postgresql-18 postgresql-client-18
sudo systemctl enable --now postgresql
pg_lsclusters
```

The repository helper adds the official PostgreSQL package repository. Review prompts before accepting. If your Ubuntu release is not supported, select a supported LTS image. Check the actual cluster port using `pg_lsclusters` (5432 assumed below).

### Step 3: Configure remote connections

```bash
sudo -u postgres psql -c 'SHOW config_file;'
sudo -u postgres psql -c 'SHOW hba_file;'
sudo nano /etc/postgresql/18/main/postgresql.conf
```

Set `listen_addresses = 'localhost,YOUR_DB_PRIVATE_IP'` using the actual address. For secure remote connections configure PostgreSQL with a trusted TLS certificate and private key, enable `ssl = on`, and use a DNS name matching the certificate. See https://www.postgresql.org/docs/current/ssl-tcp.html. Ubuntu's default self-signed certificate is not sufficient for verified remote connections.

```bash
sudo nano /etc/postgresql/18/main/pg_hba.conf
```

Add this rule, replacing the backend IP with its actual private address:

```text
hostssl carepulse carepulse 10.0.2.4/32 scram-sha-256
```

Save (Ctrl+O, Enter, Ctrl+X). Restart and check:

```bash
sudo systemctl restart postgresql
sudo systemctl status postgresql
sudo -u postgres psql
```

Proceed to **Common initialization** below. For initial administration via pgAdmin, use an SSH tunnel and a password-enabled administrator or initialize directly using the local `postgres` OS account as shown.

## Option 2: PaaS — Azure Database for PostgreSQL Flexible Server (recommended)

### Step 1: Provision the server

Open https://portal.azure.com and create a resource group `rg-carepulse`. Create a VNet `vnet-carepulse` (10.0.0.0/16), frontend subnet 10.0.1.0/24 and backend subnet 10.0.2.0/24. For the private database option add a dedicated delegated subnet 10.0.3.0/24 (`Microsoft.DBforPostgreSQL/flexibleServers`).

Search for **Azure Database for PostgreSQL flexible servers** and select Create.

| Field | Suggested value |
|---|---|
| Resource group | rg-carepulse |
| Server name | carepulse-db-YOUR_UNIQUE_SUFFIX |
| Region | Central India or a supported region |
| Version | 18 |
| Compute | Burstable, smallest suitable development SKU |
| Storage | 32 GiB if available |
| High availability | Disabled for lab |
| Authentication | PostgreSQL authentication |
| Administrator | careadmin |
| Password | A unique strong password |

### Step 2: Networking and firewall

For the simplest pgAdmin setup select Public access (allowed IP addresses). Add your workstation public IP and the backend VM's **actual outbound public IP** as separate firewall rules (the backend may use a public IP or NAT Gateway). Do not enable access from every Azure service or all internet IPs. Remove your workstation rule after setup if not required.

Alternatively select Private access (VNet integration), the delegated database subnet and a linked private DNS zone. Then run SQL from the backend VM; local pgAdmin needs private connectivity or an SSH tunnel with correct TLS hostname validation. Keep both VMs in the same VNet. Private VMs need explicit outbound internet connectivity for installing packages (for example NAT Gateway). Review and create. Copy the server FQDN from Overview.

### Step 3: Connect using pgAdmin 4 (public-access option)

Install pgAdmin from https://www.pgadmin.org/download/. Open Servers > Register > Server. General name: `CarePulse-Azure`. Connection: server FQDN, port 5432, maintenance database `postgres`, username `careadmin`, administrator password. Set SSL mode `verify-full` and configure a trusted CA bundle using the Azure TLS guidance. Do not save passwords on shared computers. Click Save.

Alternatively, on a network-authorized Ubuntu VM:

```bash
sudo apt update
sudo apt install -y postgresql-client git ca-certificates
export DB_HOST=YOUR_SERVER.postgres.database.azure.com
export PGSSLMODE=verify-full
export PGSSLROOTCERT=/etc/ssl/certs/ca-certificates.crt
psql -h "$DB_HOST" -U careadmin -d postgres
```

Enter the administrator password when asked. The `postgres=>` prompt means you are connected. If the TLS certificate is not trusted, consult the Azure CA guidance; do not disable TLS.

## Common initialization — both options

### Step 1: Create the application role and database

In psql (or pgAdmin Query Tool connected to `postgres`), execute the following one-time SQL commands separately:

```sql
CREATE ROLE carepulse LOGIN;
```

In psql set the password interactively:

```text
\password carepulse
```

In pgAdmin use the role properties dialog to set the password instead. For Azure run `GRANT carepulse TO careadmin;` as the administrator. On a self-managed VM the local postgres superuser can create the database directly.

```sql
CREATE DATABASE carepulse OWNER carepulse;
```

Do not run CREATE DATABASE inside a transaction. Exit psql with `\q`. Do not reuse the administrator password for the application.

### Step 2: Clone the database repository

From an authorized machine with Git installed (replace YOUR_USERNAME):

```bash
git clone https://github.com/YOUR_USERNAME/carepulse-database.git
cd carepulse-database
ls -la
```

### Step 3: Execute scripts in order

For Azure use the environment variables set above. For IaaS on the database VM use `export DB_HOST=localhost` and `export PGSSLMODE=prefer` for local-only initialization; remote backend connections must use verified TLS. If local password authentication is not enabled, configure a narrow localhost SCRAM rule first.

```bash
psql -h "$DB_HOST" -U carepulse -d carepulse -v ON_ERROR_STOP=1 -1 -f 01-schema.sql
psql -h "$DB_HOST" -U carepulse -d carepulse -v ON_ERROR_STOP=1 -1 -f 02-demo-data.sql
```

Enter the application password. `-f` executes the file, `-1` uses a single transaction and `ON_ERROR_STOP` stops on errors. Do not repeat the schema on an initialized database.

With pgAdmin, register a new connection using the `carepulse` user and database, open Query Tool, open each SQL file in order and execute with F5. Confirm the user owns the tables.

### Step 4: Verify data

```bash
psql -h "$DB_HOST" -U carepulse -d carepulse
```

```sql
SELECT count(*) FROM departments;
SELECT count(*) FROM appointments;
SELECT count(*) FROM equipment;
SELECT sum(beds), sum(occupied), sum(beds-occupied) FROM departments;
```

Expected fresh-demo results: 6 departments, 24 appointments, 18 assets, 160 beds, 110 occupied, 50 available. Exit with `\q`.

## Connection string for the backend

```text
postgresql://carepulse:ENCODED_PASSWORD@YOUR_SERVER.postgres.database.azure.com:5432/carepulse?sslmode=verify-full&sslrootcert=/etc/ssl/certs/ca-certificates.crt
```

For IaaS replace the hostname and CA path with the configured certificate-matching DNS name and trusted CA. URL-encode special characters in passwords. Store the URI only in the backend `.env`, never GitHub. Move to the query service README after verification.

## Troubleshooting

- Timeout: check actual source/outbound IP, firewall, VNet, DNS and port 5432.
- Authentication failure: check username, password and database name.
- Missing tables: verify the scripts ran against `carepulse` as the application user.
- TLS failure: validate hostname and CA trust, not by disabling verification.

Azure resources may incur charges. This project has not been deployed in a live Azure subscription. Official guidance: https://learn.microsoft.com/en-us/azure/postgresql/ and https://www.postgresql.org/download/linux/ubuntu/.
