# RetailMedia Pulse 📡

**RetailMedia Pulse** is an end-to-end streaming data pipeline designed for real-time retail media advertising analytics.

## Key Features
* **Event Streaming Producer:** Modular Python producer publishing simulated real-time ad engagement logs (`impression`, `click`, `conversion`).
* **Low-Latency Ingestion:** Direct GCP Pub/Sub to BigQuery subscription streaming using schema matching.
* **Fault-Tolerant DLQ Architecture:** Automatic dead-letter queue routing for malformed or unparseable payloads with complete Pub/Sub metadata auditing (`ad_events_dlq`).
* **Analytical Reporting Layer:** Automated BigQuery SQL views (`vw_ad_performance_summary`, `vw_hourly_traffic_trends`, `vw_user_engagement`) computing CTR, CPC, and conversion metrics on live stream data.
* **100% Infrastructure as Code:** Provisioned and managed entirely via Terraform (`main.tf`).

## Project Structure

```text
retailmedia-pulse/
├── LICENSE.txt
├── README.md
├── src/
│   ├── generator.py            # Logic for generating simulated ad payload data
│   ├── producers/
│   │   ├── producer.py        # Stream producer publishing valid events to GCP Pub/Sub
│   │   └── test_dlq.py        # Producer script for testing Dead-Letter Queue (valid & malformed payloads)
│   └── utils/                 # Utility scripts and helper functions
├── terraform                   # Executable Terraform binary
├── terraform_config/
│   ├── main.tf                # Primary IaC configuration (Pub/Sub, BigQuery tables & views, DLQ)
│   ├── terraform.tfstate      # Terraform state file (git-ignored)
│   └── terraform.tfstate.backup
├── terraform.zip              # Compressed binary archive
└── venv/                      # Local Python virtual environment (git-ignored)
```

## Prerequisites

Before running this configuration, ensure you have installed:
* [Terraform CLI](https://developer.hashicorp.com/terraform/downloads) (v1.5+)
* Cloud CLI (e.g., [AWS CLI](https://aws.amazon.com/cli/) or [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/)) configured with appropriate permissions.

## Getting Started

### 1. Initialize Working Directory
Initialize the backend and download required provider plugins:
```bash
terraform init
```

### 2. Review Execution Plan
Generate and inspect the execution plan:
```bash
terraform plan
```

### 3. Apply Configuration
Provision the infrastructure:
```bash
terraform apply
```

### 4. Teardown / Cleanup
To destroy all provisioned infrastructure:
```bash
terraform destroy
```

## Security & Best Practices
* Never commit `terraform.tfvars` files containing secret keys or API credentials.
* Remote state storage should be configured (e.g., AWS S3 + DynamoDB lock) for team collaboration.



### 📊 Analytical Query Results

#### 1. Ad Performance & CTR Summary
![Ad Performance and CTR Summary Query Output](assets/vw_ad_performance_summary.jpeg)

#### 2. Hourly Traffic & Spend Trends
![Hourly Traffic Trends Output](assets/vw_hourly_traffic_trends.jpeg)

#### 3. Top Engaged Users
![Top Engaged Users Output](assets/vw_user_engagement.jpeg)

