# IRIS Docker Compose Setup & Backup Management Guide

Complete guide for setting up IRIS using **docker-compose** and easily switching between different backups.

---

## ⚡ Quick Start (5 minutes)

### 1️⃣ Create .env File

```bash

# Copy the template to create .env
cp .env.template .env

# Optional: Edit if you need different ports or password
nano .env

```

**Default values in `.env.template`:**

```bash

IRIS_PORT_STUDIO=51773
IRIS_PORT_WEB=52773
IRIS_PORT_NATIVE=1972
IRIS_PASSWORD=SYS

```

### 2️⃣ Start Docker Container

```bash

# Start IRIS in background
docker-compose up -d

# Check if running
docker-compose ps

```

### 3️⃣ Verify It's Working

```bash

# View logs (should see "IRIS initialized")
docker-compose logs -f iris

# Or open in browser:
# http://localhost:52773/csp/sys/UtilHome.csp
# Login: SuperUser / SYS

```

### 4️⃣ Stop Docker Container

```bash

# Stop the container
docker-compose stop

# Or remove everything
docker-compose down

```

---

## Quick Overview

**Why docker-compose?**

- ✅ Everything in one file (easy to share with team)
- ✅ Cleaner commands (less typing)
- ✅ Can manage multiple services together
- ✅ Environment variables for configuration
- ✅ Reproducible setup (version controlled)

**The Process:**

1. Create `docker-compose.yml` file
2. Create `.env` file with backup name
3. Run `docker-compose up -d` to start services
4. Copy backup file into container
5. Restart container to load the data
6. Access IRIS web portal
7. To switch backups: Update `.env` → Copy new file → Restart

---

## Prerequisites

### ⚠️ IMPORTANT: IRIS.DAT Backup File Required

**Before you proceed, you MUST have an `IRIS.DAT` backup file.**

This is a database file containing your IRIS data. Without it, the container will start but have no data.

#### Where to Get IRIS.DAT

- Get it from your team lead or DevOps engineer
- Export from an existing IRIS installation
- Or download from your backup storage

#### How to Add IRIS.DAT to backup_destination

```bash
# 1. Place your IRIS.DAT file in the correct folder structure:
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

---

### Check Docker and Docker Compose

```bash
docker --version
docker-compose --version
```

Both should show version numbers.

### Backup Files Location

Your backups must be organized like this:

```directory

backup_destination/
├── alpha-1/
│   └── usr/irissys/mgr/user/IRIS.DAT
├── alpha-2/
│   └── usr/irissys/mgr/user/IRIS.DAT
└── (add more backups here)

```

Verify:

```bash

ls -lah backup_destination/
ls -lah backup_destination/alpha-1/usr/irissys/mgr/user/IRIS.DAT
ls -lah backup_destination/alpha-2/usr/irissys/mgr/user/IRIS.DAT

```

---

## Step 1: Create docker-compose.yml

Create a file named `docker-compose.yml` in your project root directory:

**File location:** `./docker-compose.yml`

**Content:**

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
      # Optional: uncomment to persist data between restarts
      # - ./iris-data:/usr/irissys/mgr
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
- Checks if IRIS is healthy
- Auto-restarts if it crashes

---

## Step 2: Create .env File

Create a file named `.env` in your project root (same directory as `docker-compose.yml`):

**File location:** `./.env`

**Content:**

```bash

# IRIS Configuration
IRIS_PASSWORD=password

# Port Configuration (change if ports conflict)
IRIS_PORT_STUDIO=51773
IRIS_PORT_WEB=52773
IRIS_PORT_NATIVE=1972

# Backup Configuration (change this to switch backups)
IRIS_BACKUP_NAME=alpha-2

```

**Explanation:**

- `IRIS_PASSWORD` - Login password for IRIS (default: "password")
- `IRIS_PORT_*` - Ports to expose (change if they conflict with other services)
- `IRIS_BACKUP_NAME` - Which backup to use (alpha-1, alpha-2, etc.)

---

## Step 3: Start IRIS Container

From your project directory, run:

```bash

# Start IRIS service in background
sudo docker-compose up -d iris

```

**What this does:**

- Creates the container named `my-iris`
- Starts it in the background (`-d`)
- Exposes the ports defined in `.env`

### Verify It's Running

```bash

sudo docker-compose ps

```

You should see:

```output

NAME      IMAGE                                   COMMAND      SERVICE   STATUS
my-iris   intersystems/iris-community:latest-cd   /tini --...  iris      Up X seconds (healthy)

```

### Check the Logs

```bash

sudo docker-compose logs iris

```

Wait until you see:

```output

[Utility.Event] IRIS initialized
[Generic.Event] Private webserver started on 52773

```

✅ **Container is running!**

---

## Step 4: Copy Backup File

**IMPORTANT:** Stop the container before copying the backup file. Copying while running can corrupt the database.

```bash

# Stop the container
sudo docker-compose stop iris

# Wait 5 seconds
sleep 5

# Copy your backup file (replace alpha-2 with your backup name)
sudo docker cp backup_destination/alpha-2/usr/irissys/mgr/user/IRIS.DAT my-iris:/usr/irissys/mgr/user/IRIS.DAT

# Verify file was copied
echo "✓ Backup file copied"

```

---

## Step 5: Restart Container to Load Data

```bash

# Start the container again
sudo docker-compose start iris

# Wait 30 seconds for IRIS to initialize
sleep 30

# Check logs
sudo docker-compose logs iris | tail -20

```

Look for:

```output

[Utility.Event] IRIS initialized
[Generic.Event] Private webserver started on 52773

```

✅ **Data Loaded!**

---

## Step 6: Verify Data is Loaded

### Access the IRIS Web Portal

Open your browser and go to: `http://localhost:52773`

(Or use the port from your `.env` file if you changed it)

### Login to IRIS

- **Username:** SuperUser
- **Password:** password (from `.env` file)

### Check Your Data

1. Click **"System Management"** → **"Database"** → **"Namespaces"**
2. Look for namespaces with your data
3. Or click **"Studio"** → **"Browse"** to explore classes and globals

✅ **Data Verified!**

---

## Switching Between Backups

The easiest way to switch between backups using docker-compose:

### Method 1: Edit .env File (Recommended)

```bash

# Edit the .env file
nano .env

```

Change this line:

```bash

# From:
IRIS_BACKUP_NAME=alpha-2

# To:
IRIS_BACKUP_NAME=alpha-1

```

Save the file (`Ctrl+X`, then `Y`, then `Enter`)

Then:

```bash

# Stop IRIS
sudo docker-compose stop iris

# Copy the new backup
sudo docker cp backup_destination/alpha-1/usr/irissys/mgr/user/IRIS.DAT my-iris:/usr/irissys/mgr/user/IRIS.DAT

# Start IRIS again
sudo docker-compose start iris

# Wait for initialization
sleep 30

# Verify
sudo docker-compose logs iris | tail -10

```

### Method 2: Manual Command (Fastest)

```bash

# For alpha-1
sudo docker-compose stop iris && \
sudo docker cp backup_destination/alpha-1/usr/irissys/mgr/user/IRIS.DAT my-iris:/usr/irissys/mgr/user/IRIS.DAT && \
sudo docker-compose start iris && \
sleep 30 && \
echo "✓ Switched to alpha-1"

```

---

### Team Handover Checklist

Before sharing this with your team, make sure they understand:

- [ ] How to clone the repository with `docker-compose.yml` and `.env` files
- [ ] How to run `sudo docker-compose up -d iris` to start IRIS
- [ ] How to access IRIS at `http://localhost:52773` (or configured port)
- [ ] How to login with SuperUser/password
- [ ] How to stop/start IRIS with docker-compose commands
- [ ] How to switch backups using the script or manual method
- [ ] Where to find logs if something goes wrong
- [ ] How to change IRIS password in `.env` file

---

## Complete Setup Steps (From Scratch)

If you're starting completely fresh:

```bash

# 1. Navigate to project directory
cd nbss/playcd/poc_backup_restore_pipeline/iris_restore

# 2. Create docker-compose.yml (copy from Step 1 above)
# 3. Create .env (copy from Step 2 above)

# 4. Start IRIS
sudo docker-compose up -d iris

# 5. Wait for IRIS to initialize
sleep 40

# 6. Copy backup file
sudo docker-compose stop iris
sudo docker cp backup_destination/alpha-2/usr/irissys/mgr/user/IRIS.DAT my-iris:/usr/irissys/mgr/user/IRIS.DAT

# 7. Start IRIS again
sudo docker-compose start iris

# 8. Wait 30 seconds
sleep 30

# 9. Verify in browser
echo "✓ Visit http://localhost:52773 and login with SuperUser/password"

```

---

## Next Steps

1. ✅ Create `docker-compose.yml` file
2. ✅ Create `.env` file
3. ✅ Run `sudo docker-compose up -d iris`
4. ✅ Copy backup file
5. ✅ Access IRIS at `http://localhost:52773`
6. ✅ Practice switching backups
7. ✅ Share with your team!

Good luck! 🚀
