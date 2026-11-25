# IRIS Docker Compose Setup & Backup Restoration Guide

Complete guide for setting up IRIS using **docker-compose** and restoring your IRIS.DAT backup.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Step 1: Prepare Your IRIS.DAT Backup](#step-1-prepare-your-irisdat-backup)
3. [Step 2: Create docker-compose.yml](#step-2-update-docker-composeyml)
4. [Step 3: Configure the Volume Path](#step-3-configure-the-volume-path)
5. [Step 4: Create .env File](#step-4-create-env-file)
6. [Step 5: Start IRIS Container](#step-5-start-iris-container)
7. [Step 6: Verify IRIS is Running](#step-6-verify-iris-is-running)
8. [Step 7: Access IRIS](#step-7-access-iris)
9. [Stop/Restart IRIS](#stoprestart-iris)

---

## Prerequisites

### Check Docker and Docker Compose

```bash
docker --version
docker-compose --version
```

Both should show version numbers.

### ⚠️ IMPORTANT: IRIS.DAT Backup File Required

**Before you proceed, you MUST have an `IRIS.DAT` backup file.**

This is a database file containing your IRIS data. Without it, the container will start but have no data.

#### Where to Get IRIS.DAT

- Get it from your team lead or DevOps engineer
- Export from an existing IRIS installation
- Or download from your backup storage
- **Or get sample backups** from the [demonstration_backups repository](https://github.com/NHSDigital/breast-screening-data/tree/main/demonstration_backups)

---

## Step 1 Prepare Your IRIS.DAT Backup

### How to Add IRIS.DAT to backup_destination

```bash
# 1. Create the backup folder structure:
mkdir -p backup_destination/alpha-1/usr/irissys/mgr/user/

# 2. Copy your IRIS.DAT file to this location:
cp /path/to/your/IRIS.DAT backup_destination/alpha-1/usr/irissys/mgr/user/IRIS.DAT

# 3. Verify the file exists:
ls -lah backup_destination/alpha-1/usr/irissys/mgr/user/IRIS.DAT
```

Expected output:

```output
-rw-r--r-- 1 user group 2.5G Nov 19 12:00 backup_destination/alpha-1/usr/irissys/mgr/user/IRIS.DAT
```

✅ **If you see the IRIS.DAT file listed, you're ready to proceed!**

### Backup Folder Structure

Your backups must be organized like this:

```directory
backup_destination/
├── alpha-1/
│   └── usr/irissys/mgr/user/IRIS.DAT
├── alpha-2/
│   └── usr/irissys/mgr/user/IRIS.DAT
└── (add more backups here)
```

Verify all backups:

```bash
ls -lah backup_destination/alpha-1/usr/irissys/mgr/user/IRIS.DAT
ls -lah backup_destination/alpha-2/usr/irissys/mgr/user/IRIS.DAT
```

---

## Step 2 Update docker-compose.yml

There's already a `docker-compose.yml` file in your project. You just need to verify/update it:

**File location:** `./docker-compose.yml`

**Current Content:**

```yaml
version: '3.8'

services:
  iris:
    image: intersystems/iris-community:latest-cd
    container_name: my-iris
    ports:
      - "${IRIS_PORT_STUDIO}:51773"
      - "${IRIS_PORT_WEB}:52773"
      - "${IRIS_PORT_NATIVE}:1972"
    environment:
      - IRIS_PASSWORD=${IRIS_PASSWORD}
    volumes:
      # Mount your chosen IRIS.DAT backup file to restore
      # - Example ./backup_destination/alpha-1/usr/irissys/mgr/user/IRIS.DAT:/usr/irissys/mgr/user/IRIS.DAT
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:52773/csp/sys/UtilHome.csp"]
      interval: 10s
      timeout: 5s
      retries: 30
    restart: unless-stopped
```

**What this does:**

- Uses IRIS Community Edition image
- Exposes ports for Studio (51773), Web (52773), and Native (1972)
- Sets IRIS password from `.env` file
- Mounts your IRIS.DAT backup file (see next step)
- Checks if IRIS is healthy
- Auto-restarts if it crashes

✅ **This file is already configured correctly - no changes needed unless you want to use a different backup!**

---

## Step 3 Configure the Volume Path

The **volumes** section tells Docker which IRIS.DAT backup file to restore. **This is the file that will be loaded into IRIS.**

### Choose Which Backup to Restore

Update the volume path in `docker-compose.yml` based on which backup you want to restore:

**To restore from alpha-1:**

```yaml
    volumes:
      - ./backup_destination/alpha-1/usr/irissys/mgr/user/IRIS.DAT:/usr/irissys/mgr/user/IRIS.DAT
```

### Understanding the Volume Path

The volume configuration format is: `HOST_PATH:CONTAINER_PATH`

- **LEFT side** (`./backup_destination/alpha-1/...`) = Your IRIS.DAT backup file on your machine (**the file being RESTORED FROM**)
- **RIGHT side** (`:/usr/irissys/mgr/user/IRIS.DAT`) = Path inside the Docker container (where IRIS will READ this file)

**When Docker starts, it loads the backup file from the LEFT side into IRIS inside the container.**

✅ **Make sure the LEFT side path matches the backup you want to restore!**

---

## Step 4 Create .env File

Create a file named `.env` in your project root (same directory as `docker-compose.yml`):

**File location:** `./.env`

**Content:**

```bash
# IRIS Configuration
IRIS_PASSWORD=SYS

# Port Configuration (change if ports conflict)
IRIS_PORT_STUDIO=51773
IRIS_PORT_WEB=52773
IRIS_PORT_NATIVE=1972
```

**Explanation:**

- `IRIS_PASSWORD` - Login password for IRIS (default: "SYS" for community edition)
- `IRIS_PORT_*` - Ports to expose (change if they conflict with other services on your machine)

---

## Step 5 Start IRIS Container

From your project directory, run:

```bash
# Start IRIS in background
docker-compose up -d

# Check if running
docker-compose ps
```

**What this does:**

- Creates and starts the container named `my-iris`
- Mounts your IRIS.DAT backup file into the container
- Exposes the ports defined in `.env`
- Automatically loads your backup data

---

## Step 6: Verify IRIS is Running

### Check Container Status

```bash
docker-compose ps
```

You should see:

```output
NAME      IMAGE                                   COMMAND      SERVICE   STATUS
my-iris   intersystems/iris-community:latest-cd   /tini --...  iris      Up 15 seconds (healthy)
```

### Check the Logs

```bash
docker-compose logs -f iris
```

Wait until you see:

```output
[Utility.Event] IRIS initialized
[Generic.Event] Private webserver started on 52773
```

✅ **Container is running and your backup data is loaded!**

---

## Step 7 Access IRIS

### Open IRIS Web Portal

Open your browser and go to `http://localhost:52773/csp/sys/UtilHome.csp`

(Or use the port from your `.env` file if you changed it)

### Login to IRIS

- **Username:** SuperUser
- **Password:** SYS (or whatever password you set in `.env`)

### Verify Your Data is Loaded

1. Click **"System Management"** → **"Database"** → **"Namespaces"**
2. Look for namespaces with your data
3. Or click **"Studio"** → **"Browse"** to explore classes and globals

✅ **Data Verified! IRIS is ready to use!**

---

## Stop/Restart IRIS

### Stop IRIS (Keep Container, Can Restart Later)

```bash
docker-compose stop
```

### Restart IRIS

```bash
docker-compose restart
```

### Remove IRIS (Delete Container, Keep Image)

```bash
docker-compose down
```

### Stop All Services

```bash
docker-compose down
```
