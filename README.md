# Lab Slice Manager

A web-based application for managing mouse brain slices and experiments in the lab.

**Current Version: 2.1**

## Features

- 🐭 **Mouse Database** - Track mice with ID, sex, genotype, birth date, sacrifice date
- 🧠 **Slice Tracking** - Record brain slices with region, thickness, cryosection date, embedding matrix
- 🧪 **Experiment Logging** - Link experiments to specific slices with protocols and results
- 🏷️ **Label Printing** - Generate and print labels with customizable size and content
- ☁️ **Cloud Sync** - Automatic synchronization via Supabase (optional)
- 📱 **Works Everywhere** - Use on any device with a web browser
- 💾 **Backup/Restore** - Export and import data as JSON files
- 🔒 **Magic Link Auth** - No passwords to remember

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
| `CHANGELOG.md` | Version history and changes |
| `migrations/` | Database migration scripts |

## Updating

1. Always backup your data first!
2. Check `CHANGELOG.md` for what's new
3. If database changes are required, run the migration script first
4. Replace `index.html` with the new version

See Section 9 of the Deployment Manual for detailed update instructions.

## Tech Stack

- Frontend: React 18 (via CDN)
- Styling: Tailwind CSS
- Backend: Supabase (PostgreSQL + Auth)
- Hosting: GitHub Pages (or any static host)

## License

For lab use. Feel free to modify for your needs.
