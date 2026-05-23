# 🎮 Palworld Distributed Hosting System

A Dockerized multiplayer hosting system for Palworld that allows a friend group to safely host and transfer a shared world between different PCs with automated backups, synchronization, Discord notifications, and low-latency multiplayer connectivity.

Instead of paying for a dedicated cloud server, this system allows any trusted member of the group to temporarily become the host while preserving world progress automatically.

> ⚠️ **Platform Support**
>
> This project currently supports **Windows only** because the orchestration layer is built using PowerShell, Windows Forms, and Windows-specific automation workflows.
>
> Docker Desktop for Windows is required.
> 
# ✨ Features

- 🐳 Dockerized Palworld dedicated server
- 💾 Automated backup and restore pipeline
- ☁️ Google Drive synchronized world persistence
- 🔒 Distributed lock system to prevent save corruption
- 🌐 Playit.gg UDP tunnel integration
- 📢 Discord webhook notifications
- 🖥️ Windows Forms dashboard UI
- 📝 Cloud-based logging system
- 🛡️ Graceful shutdown & backup workflow
- ⚡ One-click server orchestration

# 🏗️ Architecture Overview

This system consists of multiple coordinated layers:

- **Docker Compose Infrastructure**
  - Runs the Palworld dedicated server
  - Handles persistent Docker volumes
  - Uses a utility container for permission management

- **PowerShell Orchestration Engine**
  - Controls startup/shutdown lifecycle
  - Automates backup and restore operations
  - Performs health checks and synchronization

- **Distributed Save Synchronization**
  - Stores compressed world backups in shared cloud storage
  - Allows world transfer between different hosts

- **Networking Layer**
  - Uses Playit.gg UDP tunneling instead of router port-forwarding
  - Enables multiplayer access without public IP configuration

- **Discord Integration**
  - Sends automated lifecycle notifications to the group

# 🌐 Networking Strategy

Instead of traditional router port-forwarding, this project uses Playit.gg UDP tunneling to expose the locally hosted Palworld server over the internet.

## Benefits

- No router configuration required
- Works behind CGNAT
- Easier setup for non-technical users
- Stable low-latency multiplayer connectivity
- Faster onboarding for friends joining the server

# 🔄 System Workflow

```text
Player Starts Server
        ↓
Acquire Distributed Lock
        ↓
Restore Latest Backup
        ↓
Start Docker Container
        ↓
Expose via Playit.gg Tunnel
        ↓
Send Discord Notification
        ↓
Players Join Game
        ↓
Graceful Shutdown
        ↓
Create Backup Archive
        ↓
Sync Save to Shared Cloud Storage
        ↓
Release Lock
```

# 📂 Project Structure

```text
.
├── compose.yaml
├── Launcher-Dashboard.bat
├── PalApp.ps1
├── PalEngine.ps1
├── .env.example
├── .gitignore
├── LocalBackups/
└── README.md
```
# 🛠️ Prerequisites

Before starting, install and configure the following tools:

## 1. Docker Desktop

Install:
https://www.docker.com/products/docker-desktop/

Make sure Docker Engine is running before launching the dashboard.

---

## 2. Google Drive Desktop

Install Google Drive Desktop and ensure the shared synchronization folder is fully synced locally.

---

## 3. Playit.gg Agent

Install:
https://playit.gg/download

Keep the Playit agent running while hosting the server.

# 🚀 Initial Setup

## Step 1 — Clone Repository

```bash
git clone https://github.com/amitmehara2302/Palworld-Distributed-Architecture.git
cd Palworld-Distributed-Architecture
```

---

## Step 2 — Create Environment File

Create a `.env` file in the project root.

Example:

```env
# Discord Webhook
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/your_webhook_here"

# Shared Cloud Folder
SHARED_CLOUD_FOLDER="G:\My Drive\Palworld_Squad_Sync"

# Auto-filled by application
PLAYER_NAME=""

# Server password
SERVER_PASSWORD="your_password_here"

# Enable or disable cloud logging
LOGGING="true"
```
# 🌐 Playit.gg Tunnel Setup

If you are hosting the server:

1. Open the Playit.gg agent
2. Log into the Playit.gg dashboard
3. Create a new UDP tunnel
4. Configure:
   - Local IP: `127.0.0.1`
   - Local Port: `8211`
5. Copy the generated public endpoint
6. Share the endpoint with friends

Example:

```text
angry-bear.auto.playit.gg:12345
```

# ▶️ Starting the Server

1. Launch:

```text
Launcher-Dashboard.bat
```

2. Enter your host/player name
3. Click:

```text
START SERVER
```

The system will automatically:

- acquire hosting lock
- restore latest world backup
- start Docker infrastructure
- initialize networking
- send Discord notification

Once the dashboard shows:

```text
[ONLINE] Server is LIVE
```

players can join.

# 🛑 Stopping the Server Safely

Always stop the server using the dashboard.

## Correct Shutdown Flow

1. Click:

```text
STOP AND BACKUP
```

2. Wait for backup completion
3. The system will:
   - gracefully stop the server
   - archive the world save
   - upload backup to shared storage
   - release distributed lock
   - send Discord notification

When the dashboard displays:

```text
[OFFLINE] Safely Backed Up
```

it is safe to close the application.

# 🔒 Safety Features

## Distributed Lock System

The application creates a shared:

```text
server.lock
```

file inside cloud storage to prevent multiple hosts from running the same world simultaneously.

This prevents:
- save corruption
- conflicting world states
- accidental overwrites

---

## Automated Backup Pipeline

Every shutdown automatically creates:

```text
.tar.gz
```

compressed save archives.

Backups are synchronized to shared cloud storage for portability across hosts.

---

## Cloud Logging

Daily operational logs are automatically generated:

```text
Logs/palworld-YYYY-MM-DD.log
```

Useful for:
- troubleshooting
- startup failures
- backup verification
- operational tracking

# 🧠 Technical Highlights

This project demonstrates:

- Docker container orchestration
- Persistent volume management
- Automated backup workflows
- Distributed synchronization
- Infrastructure automation
- Health-check retry logic
- Event-driven notifications
- Networking and UDP tunneling
- Operational tooling design
- User-focused infrastructure UX

---

# 📌 Future Improvements

- Automatic stale-lock recovery
- Backup integrity verification
- Scheduled automatic backups
- Multi-world support
- Remote monitoring dashboard
- Cross-platform launcher support
- Automatic Playit.gg endpoint detection

# 📄 License

This project is intended for educational and personal multiplayer hosting purposes.
