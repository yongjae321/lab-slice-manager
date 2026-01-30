# Lab Slice Manager

A web-based application for managing mouse brain slices and experiments in the lab.

**Current Version: 3.0**

## Features

- 🐭 **Mouse Database** - Track mice with ID, sex, genotype, birth date, sacrifice date
- 🧠 **Slice Tracking** - Record brain slices with region, thickness, cryosection date, embedding matrix
- 🧪 **Multi-Slice Experiments** - Link multiple slices to a single experiment with per-slice treatments
- 🏷️ **Label Printing** - Generate and print labels with experiment ID, mouse info, and treatment
- ☁️ **Cloud Sync** - Automatic synchronization via Supabase (optional)
- 📱 **Works Everywhere** - Use on any device with a web browser
- 💾 **Backup/Restore** - Export and import data as JSON files
- 🔒 **Magic Link Auth** - No passwords to remember

## What's New in v3.0

**Major Architecture Change**: Experiments now support multiple slices from different mice!

- Create experiments first, then add slices to them
- Or start from a slice and create/join an experiment
- Each slice in an experiment has its own treatment/protocol field
- Compare slices from different mice in the same experiment
- Print labels showing experiment + slice + treatment info

## Quick Start

### Offline Mode (No Setup Required)
1. Download `index.html`
2. Open in any web browser
3. Click "Continue Offline"
4. Start using!

### Online Mode (Cloud Sync)
See the [Deployment Manual](DEPLOYMENT_MANUAL.md) for complete setup instructions.

## Files in This Repository

| File | Description |
|------|-------------|
| `index.html` | The main application |
| `DEPLOYMENT_MANUAL.md` | Complete setup and usage guide |
| `ARCHITECTURE.md` | Technical documentation |
| `CHANGELOG.md` | Version history and changes |
| `fresh_schema_v3.sql` | Database schema for new installations |

## ⚠️ Upgrading from v2.x

**Version 3.0 requires a fresh database schema.** The old experiment structure (one experiment per slice) is incompatible with the new many-to-many architecture.

**Before upgrading:**
1. Export your data from v2.x (Database icon → Export)
2. Save the backup file safely
3. Note: Old experiments will need to be re-created manually

**To upgrade:**
1. Run `fresh_schema_v3.sql` in Supabase SQL Editor (this drops old tables!)
2. Replace `index.html` with the new version
3. Re-enter data or selectively import mice/slices from backup

## Data Model

```
┌──────────┐      ┌──────────┐      ┌───────────────────┐      ┌─────────────┐
│  MICE    │──┐   │  SLICES  │──┐   │ EXPERIMENT_SLICES │   ┌──│ EXPERIMENTS │
│          │  └──▶│          │  └──▶│   (junction)      │◀──┘  │             │
│ M-XXXX   │      │ S-XXXX   │      │ treatment field   │      │ E-XXXX      │
└──────────┘      └──────────┘      └───────────────────┘      └─────────────┘
   One              Many               Many-to-Many              Independent
```

## Tech Stack

- Frontend: React 18 (via CDN)
- Styling: Tailwind CSS
- Backend: Supabase (PostgreSQL + Auth)
- Hosting: GitHub Pages (or any static host)

## License

For lab use. Feel free to modify for your needs.
