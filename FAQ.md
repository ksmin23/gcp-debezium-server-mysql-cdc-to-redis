# FAQ

## Table of Contents
- [Q1. Why do I get a "permission denied" error when running `docker pull` on the `mysql-client-vm` instance?](#q1-why-do-i-get-a-permission-denied-error-when-running-docker-pull-on-the-mysql-client-vm-instance)
- [Q2. Why do I get a configuration file load error when running `docker run` on the `mysql-client-vm` instance?](#q2-why-do-i-get-a-configuration-file-load-error-when-running-docker-run-on-the-mysql-client-vm-instance)
- [Q3. How can a Docker container access a Redis instance running on the host machine?](#q3-how-can-a-docker-container-access-a-redis-instance-running-on-the-host-machine)
- [Q4. How can I verify that the Debezium server is correctly sending data to Redis Streams?](#q4-how-can-i-verify-that-the-debezium-server-is-correctly-sending-data-to-redis-streams)
- [Q5. Can you provide a Terraform command cheatsheet?](#q5-can-you-provide-a-terraform-command-cheatsheet)
- [Q6. `terraform apply` succeeded, but why weren't the GCS files copied to the VM instance?](#q6-terraform-apply-succeeded-but-why-werent-the-gcs-files-copied-to-the-vm-instance)

---

## Q1. Why do I get a "permission denied" error when running `docker pull` on the `mysql-client-vm` instance?

**Error Message:**
```
$ docker pull debezium/server:3.0.0.Final
Got permission denied while trying to connect to the Docker daemon socket at unix:///var/run/docker.sock: Post "http://%2Fvar%2Frun%2Fdocker.sock/v1.24/images/create?fromImage=debezium%2Fserver&tag=3.0.0.Final": dial unix /var/run/docker.sock: connect: permission denied
```

**Answer:**
This error occurs because the currently logged-in user does not have the necessary permissions to access the Docker daemon socket file (`/var/run/docker.sock`).

### 1. Temporary Solution: Use `sudo`
The simplest way to resolve this is to run the `docker` command with administrative privileges by prepending `sudo`.
```bash
sudo docker pull debezium/server:3.0.0.Final
```
However, this requires you to type `sudo` every time you run a `docker` command.

### 2. Permanent Solution: Add User to the `docker` Group (Recommended)
To avoid the inconvenience of using `sudo` every time, you can add the current user to the `docker` group.

1.  **Add the current user to the `docker` group.**
    ```bash
    sudo usermod -aG docker $USER
    ```

2.  **To apply the changes, you can either log out and log back in, or open a new terminal.**
    Alternatively, you can activate the new group membership immediately in a new shell by running:
    ```bash
    newgrp docker
    ```
Now you can run `docker` commands without `sudo`.

---

## Q2. Why do I get a configuration file load error when running `docker run` on the `mysql-client-vm` instance?

**Error Message:**
```
$ sudo docker run -it --name debezium -p 8080:8080 -v $PWD/config:/debezium/config debezium/server:3.0.0.Final 

Failed to load mandatory config value 'debezium.sink.type'. Please check you have a correct Debezium server config in /debezium/conf/application.properties or required properties are defined via system or environment variables.
```

**Answer:**
This error occurs because the Debezium server cannot find the mandatory configuration property `debezium.sink.type` upon startup. This is likely because the `application.properties` file is missing from the `conf` directory mounted in the `docker run` command, or the property is not defined within the file.

**Solution:**

1.  **Navigate to the `debezium` directory.**
    ```bash
    cd debezium
    ```

2.  **Create a `conf` directory to hold the configuration file.**
    ```bash
    mkdir conf
    ```

3.  **Copy the example configuration file into the `conf` directory.**
    ```bash
    cp application.properties.example conf/application.properties
    ```

4.  **Open `conf/application.properties` and update the required values to match your GCP and database environment.**
    *   `debezium.sink.type=bigquery`
    *   `debezium.sink.bigquery.project=` (Your GCP Project ID)
    *   `debezium.sink.bigquery.dataset=` (Your BigQuery Dataset Name)
    *   `debezium.source.database.hostname=` (The Private IP of your Cloud SQL MySQL instance)
    *   `debezium.source.database.user=` (Database user)
    *   `debezium.source.database.password=` (Database password)
    *   `debezium.source.database.include.list=` (Database name)
    *   `debezium.source.table.include.list=` (Table name, in `database.table` format)

5.  **Run the Docker container again from within the `debezium` directory.**
    ```bash
    sudo docker run -it --name debezium -p 8080:8080 -v $PWD/conf:/debezium/conf debezium/server:3.0.0.Final
    ```

---

## Q3. How can a Docker container access a Redis instance running on the host machine?

**Answer:**
Since containers use an isolated network, `localhost` inside a container refers to the container itself. To access services on the host machine, you need to use one of the following methods.

### Method 1: Use `host.docker.internal` (Most Recommended)
Docker provides a special DNS name, `host.docker.internal`, which resolves to the host machine's IP address. You can configure your application inside the container to connect to Redis using `host.docker.internal` instead of `localhost`.

**- For Docker Desktop (Mac, Windows):**
`host.docker.internal` is automatically mapped to the host's IP. You can use it without any extra configuration.

**- For Linux Environments:**
To use `host.docker.internal`, you must manually map it by adding the `--add-host` option to your `docker run` command. Here is an example for the `debezium` container:
```bash
sudo docker run -it --name debezium --add-host=host.docker.internal:host-gateway -p 8080:8080 -v $PWD/conf:/debezium/config debezium/server:3.0.0.Final
```
> **Note:** `host-gateway` is a special Docker keyword that resolves to the host's IP address.
> 
> **Related Documentation:** [Docker run reference](https://docs.docker.com/reference/cli/docker/container/run/#add-host)

**Example (`redis-cli`):**
```bash
# Run from inside a Docker container
redis-cli -h host.docker.internal -p 6379
```

### Method 2: Use Host Network Mode (`--network="host"`)
This makes the container share the host's network stack. By adding the `--network="host"` option to `docker run`, you can connect to the host's services using `localhost` from inside the container.

**Disadvantage:** This eliminates the network isolation benefit of containers and can lead to port conflicts.

**Example:**
```bash
sudo docker run -it --network="host" --name my-app my-app-image
```

### ⚠️ Important: Check Host Redis Configuration
If you still can't connect, especially if you see a `DENIED Redis is running in protected mode` error, you need to configure the host's Redis to allow external connections.

**Solution:** Open the `redis.conf` file on your host machine and apply one of the following changes:

**Option 1: Disable Protected Mode (Recommended)**
Change the `protected-mode` setting to `no`.
```
# Inside redis.conf
protected-mode no
```

**Option 2: Change the Bind Address**
Comment out the `bind` setting (`# bind 127.0.0.1`) or change it to `0.0.0.0` to allow connections from any IP.
```
# Inside redis.conf
# bind 127.0.0.1
# OR
bind 0.0.0.0
```

After modifying the configuration file, you must restart the Redis server for the changes to take effect.

> **Security Warning:** These settings allow external connections to Redis and are recommended for development environments only. In a production environment, you must protect the Redis port (6379) with a firewall or set up password authentication.

---

## Q4. How can I verify that the Debezium server is correctly sending data to Redis Streams?

**Answer:**
You can use `redis-cli` to directly inspect the data in the Redis Stream created by Debezium. First, you need to know the key (name) of the stream where Debezium sends data.

*   **Stream Key Format**: `debezium.source.database.server.name` value + `.` + `schema_name` + `.` + `table_name`
*   **Example**: If `server.name` in `application.properties` is `dbserver1` and you are tracking the `mydb.customers` table, the stream key will be `dbserver1.mydb.customers`.

### Method 1: Monitor the Data Stream in Real-Time (`XREAD BLOCK`)
This is the best way to see new data as it arrives in the stream.

```bash
redis-cli XREAD BLOCK 0 STREAMS <stream_key> $
```
*   `BLOCK 0`: Waits indefinitely for new data.
*   `$`: Means you only want to see the latest data that arrives from now on.

**Example:**
```bash
redis-cli XREAD BLOCK 0 STREAMS dbserver1.mydb.customers $
```
Now, any data changes in the `customers` table will immediately appear in your terminal as CDC events.

### Method 2: Read Existing Data in the Stream (`XRANGE`)
This command retrieves all data already stored in the stream from beginning to end.

```bash
redis-cli XRANGE <stream_key> - +
```
*   `-`: Represents the oldest (first) entry.
*   `+`: Represents the newest (last) entry.

**Example:**
```bash
redis-cli XRANGE dbserver1.mydb.customers - +
```

### Method 3: Check Stream Information (`XINFO`)
This command shows metadata about the stream, such as the number of messages and the last generated ID.

```bash
redis-cli XINFO STREAM <stream_key>
```

**Example:**
```bash
redis-cli XINFO STREAM dbserver1.mydb.customers
```

---

## Q5. Can you provide a Terraform command cheatsheet?

**Answer:**

### Terraform Command Cheatsheet

---

#### **1. Initializing a Project**

Initializes a working directory to begin a Terraform project. This downloads plugins, modules, and sets up the backend.

```bash
# Initialize the current directory
terraform init

# Reconfigure after changing backend settings
terraform init -reconfigure
```

---

#### **2. Planning & Validation**

Previews changes before applying them to the infrastructure and validates the syntax.

```bash
# Check code for syntax and validity
terraform validate

# Create an execution plan (preview what resources will be created/modified/deleted)
terraform plan

# Save the execution plan to a file
terraform plan -out="tfplan"
```

---

#### **3. Applying & Destroying**

Applies the planned changes to the actual infrastructure or destroys all managed infrastructure.

```bash
# Apply the planned changes
terraform apply

# Apply with a saved plan file (applies immediately without user confirmation)
terraform apply "tfplan"

# Destroy all resources managed by Terraform
terraform destroy
```

---

#### **4. Formatting Code**

Automatically formats Terraform code to the standard style.

```bash
# Format .tf files in the current directory
terraform fmt

# Format files in the current directory and all subdirectories
terraform fmt -recursive
```

---

#### **5. State Management**

Inspects and manages the state of resources managed by Terraform.

```bash
# List all resources in the current state
terraform state list

# Show detailed information about a specific resource
# Example: terraform state show 'module.network.google_compute_network.vpc'
terraform state show '<RESOURCE_ADDRESS>'

# Show the current state file in a human-readable format
terraform show

# Display the values of output variables defined in the configuration
terraform output
```

---

#### **6. Workspace Management**

Used to manage multiple environments (e.g., dev, staging, prod) with the same configuration files.

```bash
# List all workspaces
terraform workspace list

# Create a new workspace named 'dev'
terraform workspace new dev

# Switch to the 'staging' workspace
terraform workspace select staging
```

---

### **Typical Workflow**

1.  **`terraform init`**: Run once at the start of a project (or again if modules/providers change).
2.  **`terraform fmt -recursive`**: Run after modifying code to ensure consistent formatting.
3.  **`terraform validate`**: Check for syntax errors in your code.
4.  **`terraform plan`**: Review the changes that will be made.
5.  **`terraform apply`**: Apply the planned changes to your infrastructure.
6.  (If needed) **`terraform destroy`**: Clean up all created resources.

---

## Q6. `terraform apply` succeeded, but why weren't the GCS files copied to the VM instance?

**Answer:**

### Most Likely Cause: Timing Issue (Permission Granting)

The most probable reason is a timing mismatch between **when the VM was created and its startup script ran** and **when the service account was granted GCS permissions**.

The startup script (`metadata_startup_script`) executes as soon as the VM boots. At that moment, the VM's service account might not have had the necessary permissions to access GCS yet. Consequently, the `gcloud storage cp` command would fail due to a permission error.

Since the startup script only runs once on the first boot, granting permissions later will not automatically re-run the script, leaving the files uncopied.

---

### Solutions

#### Solution 1: Recreate Only the VM with Terraform (Most Recommended)

This is the cleanest approach. Target only the problematic VM resource for destruction and recreation. This ensures that when the new VM boots, its service account will already have the correct permissions, allowing the startup script to execute successfully.

1.  **Destroy only the `gce-client` module.**
    ```bash
    terraform destroy -target="module.gce-client"
    ```
    (Review the plan and type `yes` to approve.)

2.  **Run `terraform apply` again to recreate the VM.**
    ```bash
    terraform apply
    ```

#### Solution 2: Manually Re-run the Commands on the VM

Use this method if you don't want to recreate the VM or if you want to verify that the permissions are now correct.

1.  **SSH into the VM using IAP.**
    ```bash
    gcloud compute ssh mysql-client-vm --zone <your-zone>
    ```

2.  **Manually run the file copy command inside the VM.**
    First, get the GCS bucket name from your Terraform state:
    ```bash
    terraform state show 'module.gce-client.google_storage_bucket.debezium_files_bucket'
    ```
    Copy the `name` attribute from the output. Then, in the VM's SSH terminal, run the following commands:
    ```bash
    # Create the directory if it doesn't exist
    mkdir -p /root/debezium-server

    # Copy the files using the bucket name you retrieved
    gcloud storage cp --recursive gs://<YOUR_BUCKET_NAME>/debezium-server /root/
    ```

---

### Tip: Check Startup Script Logs

For future troubleshooting, you can check the VM's **serial console logs** to see any errors that occurred during the startup script's execution.

```bash
gcloud compute instances get-serial-port-output mysql-client-vm --zone <your-zone> --port 1
```