# PRD: GCP CDC Pipeline with Debezium and Redis

## 1. Overview

### 1.1. Objective
To provision a scalable, real-time data analytics and caching pipeline on Google Cloud Platform using Infrastructure as Code (IaC). This project automates the deployment of a Change Data Capture (CDC) system that streams changes from a Cloud SQL for MySQL source to a Redis instance. The pipeline utilizes a Debezium Server running in a Docker container on a Google Compute Engine (GCE) VM. The entire infrastructure is managed by Terraform.

### 1.2. Background
This project implements a modern CDC architecture for streaming database changes to a real-time data store. Instead of a traditional data warehouse pipeline, this solution combines the open-source Debezium project with Google Cloud's managed services to build a robust and self-contained system. A Debezium Server runs on a GCE instance, reads the change log from Cloud SQL, and streams the events directly into a Redis instance running on the same VM, making it ideal for caching, real-time analytics, or feeding other microservices.

## 2. Functional Requirements

### 2.1. Core Data Pipeline Components
The Terraform configuration must provision and configure the following GCP services to work in concert:

| Component | Service | Requirement |
| :--- | :--- | :--- |
| **Data Source** | Cloud SQL for MySQL | A Cloud SQL instance, accessible only via a private network (no public IP), to act as the transactional database source. Must have an `rdsadmin` user for management and a dedicated `datastream` user for CDC. |
| **CDC Engine & Sink Host** | GCE VM | A Google Compute Engine (GCE) instance to host the core services. It runs the Debezium Server in a Docker container and the Redis server. This instance must be located within the private network. |
| **CDC Engine** | Debezium Server (Docker) | A Debezium Server running as a Docker container on the GCE VM. It captures change logs from Cloud SQL and streams them to the local Redis instance. |
| **Data Sink / Cache** | Redis Server | A Redis server installed and running directly on the GCE VM. It acts as the destination (sink) for all CDC events, storing them in Redis Streams. |
| **Networking** | VPC, Subnets, PSC, Cloud NAT | Secure private networking using a custom VPC. A **Private Service Connect (PSC) endpoint** provides a stable internal IP for the Cloud SQL instance. A Cloud NAT gateway is required for the GCE instance to download software packages and the Debezium Docker image. |
| **Provisioning Helper** | Google Cloud Storage | A temporary GCS bucket is created and deleted during the `terraform apply` and `destroy` processes. It is used to copy Debezium configuration files from the local machine to the GCE VM. |

### 2.2. Key Architectural Features
- **Debezium-based CDC:** Utilizes the open-source Debezium engine, providing flexibility and reducing vendor lock-in.
- **Redis as a Real-Time Sink:** CDC events are streamed directly to Redis Streams, providing a low-latency, in-memory data store suitable for caching, real-time applications, and event-driven architectures.
- **Self-Contained Environment:** The CDC engine (Debezium) and the data sink (Redis) are co-located on the same GCE VM, simplifying the architecture and network configuration.
- **Secure by Default:** All components operate within a private VPC, with no public IPs for the database or the main GCE VM, enhancing security. Cloud SQL is accessed via a secure PSC endpoint.

## 3. Non-Functional Requirements

### 3.1. Infrastructure as Code (IaC)
- The entire infrastructure must be defined in HashiCorp Configuration Language (HCL) for Terraform.
- The code must be modular and reusable.
- A GCS bucket must be used as the backend for storing the Terraform state file (`terraform.tfstate`), ensuring state is managed remotely and securely.

### 3.2. Security
- **Principle of Least Privilege:** All service accounts must be granted only the IAM permissions necessary for their function.
    - The `datastream` database user should have the minimal required permissions for replication (`REPLICATION SLAVE`, `SELECT`, `REPLICATION CLIENT`).
    - The GCE instance's service account uses the `cloud-platform` scope to access necessary GCP APIs, including Cloud Storage for provisioning.
- **Private Networking:** All communication between GCP services must occur over the private network. The Cloud SQL instance must have its public IP disabled.
- **Secrets Management:** Database credentials for the `rdsadmin` and `datastream` users should be generated at runtime by Terraform and passed securely.

### 3.3. Configurability
- The Terraform project must be highly configurable through variables (`.tfvars`).
- Key parameters such as `project_id`, `region`, instance names, and database settings must be externalized from the core logic.
- Performance and cost-related parameters (e.g., Cloud SQL `db_tier`, GCE `machine_type`) must be configurable.

### 3.4. Naming Conventions
- All resources should follow a consistent naming convention to ensure clarity and manageability.
- **Format**: Resource names are typically composed of a prefix and a resource-specific name.

### 3.5. Monitoring and Alerting
> **Note:** This is a functional requirement that is not yet implemented in the current Terraform code.

- Basic monitoring and alerting must be configured to ensure pipeline reliability.
- **GCE VM Health:** Alerts should be created if the GCE instance's CPU utilization exceeds a defined threshold or if the instance becomes unhealthy.
- **Redis Server Health:** A Cloud Monitoring alert should be configured to trigger if the Redis process is not running on the GCE VM.

## 4. Terraform Structure & Implementation Details

### 4.1. Component Configuration Details

#### 4.1.1. Cloud SQL for MySQL
- **MySQL Version:** `MYSQL_8_0`
- **Tier:** Must be a configurable variable (e.g., `db-n1-standard-2`).
- **CDC Configuration:** The instance must be configured to support CDC through `backup_configuration.binary_log_enabled` and appropriate `database_flags` (e.g., `binlog_row_image = "full"`).
- **PSC Enabled**: The instance must be configured to allow Private Service Connect, and a PSC endpoint is created to provide a stable internal IP.
- **Database Users**: `root`, `rdsadmin`, and `datastream` users must be created with unique, randomly generated passwords.

#### 4.1.2. GCE VM (`mysql-client-vm`)
- **Startup Script:** A comprehensive startup script automates the installation of:
    - **MySQL Client**: For database interaction.
    - **Redis Server**: To act as the CDC sink.
    - **Docker Engine**: To run the Debezium server.
- **Debezium Configuration:** Configuration files from the local `debezium-server/config` directory are uploaded to a temporary GCS bucket and then copied to `/opt/debezium-server` on the VM during provisioning.
- **Debezium Image:** The `debezium/server:3.0.0.Final` Docker image is pulled on startup.

#### 4.1.3. Redis
- **Installation:** Redis is installed via `apt-get` on the GCE VM.
- **Configuration:** The `redis.conf` file is modified by the startup script to allow connections from the Debezium Docker container.
- **Data Sink:** It serves as the destination for CDC events, which are written to Redis Streams. It also stores Debezium's schema history.

### 4.2. Required Resources (High-Level)
- `google_sql_database_instance`
- `google_sql_user` (for `root`, `rdsadmin`, and `datastream`)
- `google_compute_instance` (for Debezium server, Redis, and MySQL client)
- `google_storage_bucket` (for temporary file transfer during provisioning)
- `google_project_iam_member` / `google_service_account`
- `google_compute_network`
- `google_compute_subnetwork`
- `google_compute_forwarding_rule` (for PSC)
- `google_compute_router`
- `google_compute_router_nat`
- `google_monitoring_alert_policy` (*Note: Not yet implemented*)

## 5. Deliverables

1.  A complete set of Terraform files (`.tf`) to provision the entire pipeline.
2.  A `variables.tf` file defining all configurable parameters.
3.  An example `terraform.tfvars.example` file showing users how to configure the project with sensible defaults.
4.  A `README.md` file with detailed instructions on how to initialize, plan, and apply the Terraform configuration.
5.  **Required Outputs**: The root Terraform module must output the following values after a successful `apply` for operational purposes:
    -   Cloud SQL Instance Name
    -   Cloud SQL Instance Private IP
    -   Cloud SQL PSC Endpoint IP
    -   GCE VM Instance Name
    -   GCE VM Instance Private IP
    -   Admin User Name (`rdsadmin`)
    -   Admin User Password (marked as sensitive)
    -   Debezium User Name (`datastream`)
    -   Debezium User Password (marked as sensitive)

## 6. Out of Scope

-   Custom Debezium connector development.
-   CI/CD automation for deploying the Terraform infrastructure.
-   High-availability configuration for Redis (e.g., Sentinel, Cluster).
-   Creation of applications that consume data from the Redis Streams.