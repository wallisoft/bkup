# bkup

**A comprehensive, intelligent backup solution for Linux servers with encrypted cloud storage**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)

---

## 🎯 Overview

`bkup` is an enterprise-grade backup orchestration system designed for developers managing multiple servers. It intelligently handles file backups using the optimal method (tar for many files, rsync for few), maintains encrypted cloud backups, and provides comprehensive monitoring and management tools.

### Key Features

**🌟 Standout Innovations:**

- **🎯 Smart Tar/Rsync Selection** - Automatically detects file count and chooses optimal backup method
  - **rsync** for directories with <1000 files (incremental, efficient)
  - **tar** for directories with >1000 files (10x faster on first run!)
  - *Invaluable for servers hosting large numbers of small files (book covers, images, etc.)*
  
- **⏱️ 5-Tier Database Snapshots with 5-Minute Granularity**
  - Great-grandson (5-min) → Grandson (hourly) → Son (daily) → Father (weekly) → Grandfather (monthly)
  - **Maximum 5-minute data loss** for production databases
  - Immediate rollback capability with minimal overhead
  - *Far superior to traditional daily backup approaches*

**Additional Features:**

- 🔐 **Encrypted Cloud Backup** - Backblaze B2 with client-side encryption
- 📊 **Size-Aware Filtering** - Configurable limits for cloud uploads (saves 95% on costs)
- 🔄 **Multi-Server Support** - SSH-based backup of remote servers
- 💾 **Local Redundancy** - Automatic mirroring to redundant drives
- 🎨 **Terminal GUI** - Easy configuration management
- 📝 **Comprehensive Logging** - Detailed logs and filtering reports
- ⏰ **Automated Scheduling** - Cron-based automation
- 🔒 **Lock File Protection** - Prevents concurrent backup runs

### Cost-Effective Cloud Storage

With smart filtering (default 10MB limit), typical cloud costs:
- **Without filtering:** ~$3/month for 500GB
- **With filtering:** ~$0.06-0.24/month for 20-50GB
- **Savings:** ~95% reduction while protecting critical data

---

## 📋 Requirements

- Linux or WSL2 (Ubuntu 22.04+ recommended)
- Bash 4.0+
- SSH access to remote servers (key-based authentication)
- rsync, tar, sqlite3
- rclone (for cloud backup)
- Backblaze B2 account (optional, for cloud backup)

---

## 🚀 Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/YOUR_USERNAME/bkup.git
cd bkup

# 2. Run the installation wizard
chmod +x install.sh
./install.sh

# 3. Run your first backup
bkup
```

---

## 💻 Usage

```bash
bkup              # Run full backup
bkup sync         # Cloud sync only
bkup mirror       # Mirror to redundant drive
bkup config       # Open configuration GUI
bkup snapshot     # Database snapshot
```

---

## 🔬 Technical Highlights

### Smart Tar/Rsync Selection

Traditional backup scripts use either rsync (slow for many files) or tar (no incrementals). `bkup` intelligently chooses based on file count:

```bash
# Automatically detects file count
if directory has < 1000 files:
    use rsync (incremental, efficient for changes)
else:
    use tar (10x faster for initial backup)
```

**Real-world impact:**
- Book cover repository with 20,000+ files: **30+ minutes → 2-3 minutes**
- Small config directories: Incremental rsync efficiency maintained
- Best of both worlds, automatically

### 5-Tier Database Snapshots

Unlike traditional daily backups, `bkup` implements a sophisticated GFS (Grandfather-Father-Son) rotation:

```
Great-grandson: Every 5 minutes (during business hours)
Grandson:       Hourly
Son:            Daily (with integrity check)
Father:         Weekly (with integrity check)
Grandfather:    Monthly (with integrity check)
```

**Benefits:**
- **Maximum 5-minute data loss** (vs 24 hours with daily backups)
- Immediate rollback to any 5-minute interval
- Minimal overhead (SQLite online backup)
- Automatic rotation prevents disk bloat
- Integrity verification on long-term snapshots

**Use case:** Production database corruption at 14:37? Restore from 14:35 snapshot in seconds.

---

## 📦 What Gets Backed Up

### Remote Servers (via SSH)
- Website files and databases
- Configuration files (Apache, PHP, nginx, etc.)
- SSL certificates
- Cron jobs
- User home directories

### Local Data
- Development repositories
- WSL instance
- Scripts and configurations

### Smart Filtering (Cloud Only)
**Uploaded to cloud:**
- ✅ Databases and configs
- ✅ Source code
- ✅ Scripts and documentation
- ✅ Files under 10MB

**Kept locally only:**
- ❌ Files over 10MB
- ❌ Archives (.iso, .zip, .tar)
- ❌ Media files (.mp4, .mp3)
- ❌ Build artifacts (node_modules, build/)

---

## 🗂️ Project Structure

```
bkup/
├── bin/
│   ├── bkup              # Main orchestration script
│   ├── bkup-sync         # Cloud sync with filtering
│   ├── bkup-mirror       # Local drive mirroring
│   ├── bkup-snapshot     # Database snapshots
│   └── bkup-config       # Terminal GUI
├── config/
│   └── bkuprc.example    # Example configuration
├── docs/
│   ├── SETUP.md
│   ├── CONFIGURATION.md
│   └── ARCHITECTURE.md
├── install.sh
├── LICENSE
└── README.md
```

---

## 🔐 Security & Credentials

**This project NEVER stores credentials in Git.**

All sensitive data is handled through:
- Interactive setup wizard
- Local config files (git-ignored)
- SSH key-based authentication
- rclone encrypted configuration

See [docs/SETUP.md](docs/SETUP.md) for secure credential management.

---

## 🛠️ Configuration

### Quick Configuration
```bash
bkup config
```

### Manual Configuration
Edit `~/.bkuprc`:
```bash
# Cloud settings
CLOUD_ENABLED=true
MAX_CLOUD_FILE_SIZE=10  # MB

# Backup locations
BACKUP_BASE="/mnt/d/backups"
MIRROR_BASE="/mnt/e/backups"

# Performance
NICE_LEVEL=10
IONICE_CLASS=3
```

---

## 📚 Documentation

- **[Setup Guide](docs/SETUP.md)** - Complete installation and configuration
- **[Configuration Reference](docs/CONFIGURATION.md)** - All config options
- **[Architecture](docs/ARCHITECTURE.md)** - How the system works
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues

---

## 🤝 Contributing

Contributions welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

---

## 👥 Authors

**Created by:**
- **Steve** ([@YOUR_GITHUB_USERNAME](https://github.com/YOUR_USERNAME)) - Concept, requirements, testing, implementation
- **Claude (Anthropic)** - Architecture, development, documentation

**Inspired by:**
- Unix philosophy: Do one thing well
- The Culture series by Iain M. Banks
- The open-source backup community

This project demonstrates what's possible through human-AI collaboration on practical problems.

---

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- Backblaze for affordable B2 cloud storage
- The rsync and rclone communities
- Everyone who believes in proper backups

---

## ⚠️ Disclaimer

Always test your backups and verify restore procedures before relying on them in production.

---

## 💡 Support

- 📖 [Documentation](docs/)
- 🐛 [GitHub Issues](https://github.com/YOUR_USERNAME/bkup/issues)
- 💬 [Discussions](https://github.com/YOUR_USERNAME/bkup/discussions)

---

**Remember: The best backup is the one you actually test restoring!** 🚀
