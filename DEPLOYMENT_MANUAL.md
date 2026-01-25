# Lab Slice Manager - Deployment Manual

## Complete Step-by-Step Guide for Non-Technical Users

**Version 2.1 | January 2025**

---

## Table of Contents

1. [Quick Start (Offline Mode)](#1-quick-start-offline-mode)
2. [Setting Up Online Mode with Supabase](#2-setting-up-online-mode-with-supabase)
3. [Creating the Database Tables](#3-creating-the-database-tables)
4. [Configuring the App](#4-configuring-the-app)
5. [Hosting Your App Online](#5-hosting-your-app-online)
6. [Using the App](#6-using-the-app)
7. [Backup and Restore](#7-backup-and-restore)
8. [Database Updates & Migration](#8-database-updates--migration)
9. [Version Management & Update Workflow](#9-version-management--update-workflow)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Quick Start (Offline Mode)

If you just want to try the app right now without any setup:

### Steps:
1. **Download** the `lab-slice-manager-v2.html` file
2. **Double-click** the file to open it in your web browser (Chrome, Firefox, Edge, or Safari)
3. Click **"Continue Offline"** on the login screen
4. Start using the app!

### Notes:
- Data is saved in your browser's local storage
- Data persists on the same computer and browser
- Use **Export** to save your data as a JSON file
- Use **Import** on another computer to load your data

---

## 2. Setting Up Online Mode with Supabase

Supabase provides free cloud storage and magic link authentication. Follow these steps exactly.

### Step 2.1: Create a Supabase Account

1. Open your web browser
2. Go to: **https://supabase.com**
3. Click the **"Start your project"** button (green button)
4. You can sign up with:
   - GitHub account (easiest)
   - Or click "Sign up with email" and use any personal email
5. Verify your email if prompted

### Step 2.2: Create a New Project

1. After logging in, you'll see the Supabase Dashboard
2. Click **"New Project"** (green button)
3. Fill in the form:
   - **Organization**: Select your organization (or create one)
   - **Project name**: Type `lab-slice-manager`
   - **Database Password**: Create a strong password (write it down somewhere safe - you'll need it later!)
   - **Region**: Select the one closest to you
4. Click **"Create new project"**
5. **Wait 2-3 minutes** for the project to be set up (you'll see a loading screen)

### Step 2.3: Find Your API Keys

Once your project is ready:

1. Click **"Settings"** in the left sidebar (gear icon at the bottom)
2. Click **"API"** under "Project Settings"
3. You'll see a page with your API keys. You need TWO things:
   - **Project URL**: Looks like `https://abcdefghij.supabase.co`
   - **anon public key**: A very long string starting with `eyJ...`

4. **Copy these somewhere safe** (like a text file or notes app). You'll need them later.

---

## 3. Creating the Database Tables

Now we need to create the tables that will store your data.

### Step 3.1: Open the SQL Editor

1. In your Supabase project dashboard, click **"SQL Editor"** in the left sidebar
2. Click **"New query"** button

### Step 3.2: Copy and Run the SQL Code

1. **Copy ALL of the following code** (select it all, then Ctrl+C or Cmd+C):

```sql
-- =============================================
-- Lab Slice Manager Database Setup
-- VERSION 2.2 - January 2025
-- Copy this ENTIRE block and run it in Supabase
-- =============================================

-- Table for storing mice
CREATE TABLE mice (
  id TEXT PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  "mouseNumber" TEXT,
  labeling TEXT,
  sex TEXT,
  genotype TEXT,
  "birthDate" DATE,
  "sacrificeDate" DATE,
  notes TEXT
);

-- Table for storing brain slices
CREATE TABLE slices (
  id TEXT PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  "mouseId" TEXT REFERENCES mice(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  region JSONB,                    -- JSONB for multi-select checkboxes
  thickness INTEGER DEFAULT 16,    -- Default 16μm
  "cryosectionDate" DATE,          -- Added in v2.1
  "embeddingMatrix" TEXT DEFAULT 'TFM',  -- Added in v2.1: TFM or OCT
  "sliceNumber" INTEGER,
  quality TEXT,
  "storageLocation" TEXT,
  notes TEXT
);

-- Table for storing experiments
CREATE TABLE experiments (
  id TEXT PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  "sliceId" TEXT REFERENCES slices(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  "experimentDate" DATE,
  "dataFiles" JSONB DEFAULT '[]'::jsonb,  -- Array of file paths
  protocol TEXT,                   -- Multi-line text field
  operator TEXT,
  results TEXT,
  notes TEXT
);

-- Table for user settings (schemas, label config)
CREATE TABLE user_settings (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  mouse_schema JSONB,
  slice_schema JSONB,
  experiment_schema JSONB,
  label_config JSONB,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table for tracking database version
CREATE TABLE db_version (
  version TEXT PRIMARY KEY,
  applied_at TIMESTAMPTZ DEFAULT NOW()
);

-- Record current version
INSERT INTO db_version (version) VALUES ('2.2');

-- Enable Row Level Security (keeps each user's data private)
ALTER TABLE mice ENABLE ROW LEVEL SECURITY;
ALTER TABLE slices ENABLE ROW LEVEL SECURITY;
ALTER TABLE experiments ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;

-- Security policies: users can only see and modify their own data
CREATE POLICY "Users can manage own mice" ON mice FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users can manage own slices" ON slices FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users can manage own experiments" ON experiments FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users can manage own settings" ON user_settings FOR ALL USING (auth.uid() = user_id);

-- Done! Your database is ready.
```

2. **Paste the code** into the SQL Editor (Ctrl+V or Cmd+V)
3. Click the **"Run"** button (or press Ctrl+Enter)
4. You should see a message saying "Success. No rows returned" - this is correct!

### Step 3.3: Verify Tables Were Created

1. Click **"Table Editor"** in the left sidebar
2. You should see 5 tables listed:
   - `mice`
   - `slices`
   - `experiments`
   - `user_settings`
   - `db_version`

If you see all 5 tables, the database is ready!

**Note about updates:** The `db_version` table tracks which version of the database you have. If you ever update the app in the future, check **Section 8: Database Updates & Migration** to see if you need to run a migration query.

---

## 4. Configuring the App

Now we need to tell the app how to connect to your Supabase database.

### Step 4.1: Open the HTML File in a Text Editor

1. Find the `lab-slice-manager-v2.html` file on your computer
2. **Right-click** on the file
3. Select **"Open with"** and choose:
   - **Notepad** (Windows)
   - **TextEdit** (Mac - make sure it's in plain text mode)
   - Or any code editor like VS Code, Sublime Text, etc.

### Step 4.2: Find the Configuration Section

1. The file will open showing lots of code
2. Look near the **top of the file** (around lines 20-25)
3. Find these two lines:

```javascript
const SUPABASE_URL = ''; // e.g., 'https://xxxx.supabase.co'
const SUPABASE_ANON_KEY = ''; // Your anon/public key
```

### Option A: Configure in the App (Recommended)

**New in v2.2**: You can enter your Supabase credentials directly in the app!

1. Open the app in your browser
2. You'll see a yellow "Supabase not configured" message
3. Click **"Configure Supabase"**
4. Enter your Project URL and Anon Public Key from Step 2.3
5. Click **"Save & Reload"**

**Benefits:**
- Credentials are stored in your browser's localStorage
- You don't need to edit the HTML file
- When you update the app, your credentials are preserved!

### Option B: Edit the HTML File (Alternative)

If you prefer to hardcode the credentials:

#### Step 4.3: Add Your API Keys

1. Replace the empty quotes with your actual values from Step 2.3
2. **Important**: Keep the quotes around your values!

**Before:**
```javascript
const SUPABASE_URL = '';
const SUPABASE_ANON_KEY = '';
```

**After (example - use YOUR actual values):**
```javascript
const SUPABASE_URL = 'https://abcdefghij.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFiY2RlZmdoaWoiLCJyb2xlIjoiYW5vbiIsImlhdCI6MTY0NTUwMDAwMCwiZXhwIjoxOTYxMDc2MDAwfQ.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
```

### Step 4.4: Save the File

1. Press **Ctrl+S** (Windows) or **Cmd+S** (Mac) to save
2. Close the text editor

### Step 4.5: Test It!

1. Double-click the HTML file to open it in your browser
2. Enter your email address and click "Send Magic Link"
3. Check your email for a login link or 6-digit code
4. Click the link or enter the code
5. You should now be logged in with the "Synced" badge showing!

---

## 5. Hosting Your App Online

To access your app from any device, you need to host it on the internet.

### Option A: GitHub Pages (Recommended - 100% Free)

#### Step 5.1: Create a GitHub Account (if you don't have one)

1. Go to **https://github.com**
2. Click **"Sign up"**
3. Follow the steps to create an account
4. Verify your email

#### Step 5.2: Create a New Repository

1. Log in to GitHub
2. Click the **"+"** button in the top right corner
3. Select **"New repository"**
4. Fill in:
   - **Repository name**: `lab-slice-manager`
   - **Description**: (optional) "Brain slice experiment manager"
   - Select **"Public"** (required for free hosting)
   - Check **"Add a README file"**
5. Click **"Create repository"**

#### Step 5.3: Upload Your HTML File

1. In your new repository, click **"Add file"** > **"Upload files"**
2. Drag your `lab-slice-manager-v2.html` file into the upload area
3. **Important**: Rename it to `index.html`:
   - After uploading, click on the filename
   - Click the pencil icon to edit
   - Change the name from `lab-slice-manager-v2.html` to `index.html`
   - Scroll down and click **"Commit changes"**

#### Step 5.4: Enable GitHub Pages

1. Go to your repository's **"Settings"** tab (gear icon)
2. In the left sidebar, click **"Pages"**
3. Under "Source", select:
   - **Branch**: `main`
   - **Folder**: `/ (root)`
4. Click **"Save"**
5. Wait 1-2 minutes for deployment

#### Step 5.5: Access Your App

1. Your app is now live at: `https://YOUR-USERNAME.github.io/lab-slice-manager`
2. Replace `YOUR-USERNAME` with your actual GitHub username
3. Bookmark this URL on all your devices!

---

### Option B: Netlify Drop (Fastest - 1 Minute)

1. Go to **https://app.netlify.com/drop**
2. Drag and drop your `lab-slice-manager-v2.html` file (rename to `index.html` first)
3. Wait 30 seconds
4. You'll get a random URL like `https://random-name-12345.netlify.app`
5. Bookmark this URL!

**Note**: With the free tier, you may need to re-upload occasionally. GitHub Pages is more permanent.

---

## 6. Using the App

### Logging In

1. Go to your app URL
2. Enter your email address
3. Click **"Send Magic Link"**
4. Check your email for a login link or 6-digit code
5. Click the link OR enter the code in the app

### Adding Mice

1. Click the **"Mice"** tab
2. Click **"Add Mouse"**
3. Fill in the details:
   - Mouse Number (required)
   - Sex (required)
   - Genotype, Birth Date, Sacrifice Date, Notes (optional)
4. Click **"Add Mouse"**

### Adding Slices

1. Click the **"Slices"** tab
2. Click **"Add Slice"**
3. Select the Mouse this slice came from
4. Check the brain regions (Hippocampus, Cortex, or both)
5. Fill in other details (thickness defaults to 16μm)
6. Click **"Add Slice"**

### Adding Experiments

1. Click the **"Experiments"** tab
2. Click **"Add Experiment"**
3. Select the Slice used in this experiment
4. Fill in experiment details:
   - Experiment Date (required)
   - Data File Paths: Click **"Add Path"** to add multiple file paths (one per line)
   - Protocol, Operator, Results, Notes (optional)
5. Click **"Add Experiment"**

### Printing Labels

1. Click the **"Labels"** tab
2. Use the search dropdown to select which field to search
3. Type in the search box to filter experiments
4. Click on experiments to select them (checkbox appears)
5. Click **"Config"** to customize what appears on labels
6. Adjust font size (as small as 4pt) and label width
7. Click **"Print"** to open the print dialog

### Sorting and Searching

- **Field selector dropdown**: Choose which field to search (or "All Fields")
- **Search box**: Type to filter by the selected field
- **Sort buttons**: Click to sort by mouse number, sex, age, date, etc.
- **Filter dropdown**: Filter slices by specific mouse, or experiments by specific slice

---

## 7. Backup and Restore

### Creating a Backup

1. Click the **database icon** in the top right corner
2. Click **"Export Full Backup"**
3. A JSON file will download to your computer
4. Store this file somewhere safe (cloud drive, USB, etc.)

### Restoring from Backup

1. Click the **database icon** in the top right corner
2. Click **"Import Backup"**
3. Select your backup JSON file
4. Choose:
   - **OK (Merge)**: Adds new items without replacing existing data
   - **Cancel (Replace)**: Replaces all data with the backup

### Important Notes

- The backup file works with BOTH online and offline versions
- If Supabase ever goes down, you can still use your backup offline
- Backup regularly (weekly or after major data entry sessions)

---

## 8. Database Updates & Migration

When the app is updated with new features, the database may need to be updated too. This section explains how to handle updates.

### Understanding Version Numbers

The app version is shown in two places:
- **App version**: In the HTML file header comments (e.g., "Version 2.1")
- **Database version**: In the SQL setup comments

Always check if these match when downloading a new version of the app.

### Before Any Update: ALWAYS BACKUP FIRST!

1. Open the app
2. Click the **database icon** in the top right
3. Click **"Export Full Backup"**
4. Save the JSON file somewhere safe
5. **Do NOT proceed until you have this backup!**

---

### Scenario A: You Have NO Data Yet

If you just set up Supabase and haven't entered any real data:

1. Go to Supabase **SQL Editor**
2. Run this to remove old tables:

```sql
-- Remove old tables (ONLY if you have no data!)
DROP TABLE IF EXISTS experiments;
DROP TABLE IF EXISTS slices;
DROP TABLE IF EXISTS mice;
DROP TABLE IF EXISTS user_settings;
```

3. Copy and run the new SQL setup from the updated manual

---

### Scenario B: You Have Existing Data to Keep

If you have data you want to preserve, you need to run a **migration** query instead of recreating tables.

#### How to Find the Migration Query

Each app update that requires database changes will include a migration query. Look for:
- A "MIGRATION.sql" file included with the update
- A "Migration" section in the release notes
- Instructions from whoever provided the update

#### General Migration Process

1. **Backup your data** (see above - this is critical!)
2. Go to Supabase **SQL Editor**
3. Click **"New query"**
4. Paste the migration SQL code
5. Click **"Run"**
6. Verify no errors appeared
7. Test the app to make sure everything works
8. Keep your backup file for at least a week

---

### Version 2.1 Migration (from Version 1.0)

If you set up the database with Version 1.0 and are updating to Version 2.1, run this migration:

```sql
-- =============================================
-- Migration: Version 1.0 → Version 2.1
-- Run this ONLY if you have existing data from v1.0
-- BACKUP YOUR DATA FIRST!
-- =============================================

-- Add new columns to slices table
ALTER TABLE slices ADD COLUMN IF NOT EXISTS "cryosectionDate" DATE;
ALTER TABLE slices ADD COLUMN IF NOT EXISTS "embeddingMatrix" TEXT;

-- Convert region column from TEXT to JSONB (for checkbox multi-select)
-- This safely converts existing text values to JSON arrays
DO $$ 
BEGIN
  -- Check if region column exists and is not already JSONB
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'slices' 
    AND column_name = 'region' 
    AND data_type != 'jsonb'
  ) THEN
    -- Create temporary column
    ALTER TABLE slices ADD COLUMN region_new JSONB;
    
    -- Migrate data: convert text to JSON array
    UPDATE slices SET region_new = 
      CASE 
        WHEN region IS NULL THEN NULL
        WHEN region LIKE '[%' THEN region::JSONB
        ELSE jsonb_build_array(region)
      END;
    
    -- Drop old column and rename new one
    ALTER TABLE slices DROP COLUMN region;
    ALTER TABLE slices RENAME COLUMN region_new TO region;
  END IF;
END $$;

-- Migration complete!
-- Your existing data has been preserved and converted.
```

---

### Version 2.2 Migration (from Version 2.1)

If you're updating from Version 2.1 to Version 2.2, run this migration:

```sql
-- =============================================
-- Migration: Version 2.1 → Version 2.2
-- Run this ONLY if you have existing data from v2.1
-- BACKUP YOUR DATA FIRST!
-- =============================================

-- Add labeling column to mice table
ALTER TABLE mice ADD COLUMN IF NOT EXISTS "labeling" TEXT;

-- Add dataFiles column to experiments table (for multiple file paths)
ALTER TABLE experiments ADD COLUMN IF NOT EXISTS "dataFiles" JSONB DEFAULT '[]'::jsonb;

-- Update version tracking
INSERT INTO db_version (version, notes) 
VALUES ('2.2', 'Added labeling field, dataFiles for multiple paths')
ON CONFLICT (version) DO UPDATE SET applied_at = NOW();

-- Migration complete!
```

**What's new in v2.2:**
- New "Labeling" field for mice
- Experiments can now have multiple data file paths (stored as an array)
- All panels have field-specific search (dropdown to select which field to search)
- Column order in tables now reflects schema order (reorder fields in Settings to change display order)
- Supabase credentials stored in browser (no need to re-enter when updating)

---

### What If Something Goes Wrong?

1. **Don't panic** - you have a backup!
2. If the app shows errors after migration:
   - Export any new data you may have added
   - Use the **"Continue Offline"** mode temporarily
   - Contact whoever maintains the app for help
3. If you need to restore from backup:
   - The backup works in offline mode even if Supabase has issues
   - You can import the backup to restore all your data

---

### Recording Your Database Version

It's helpful to track which version your database is on. After any migration, run this to record the version:

```sql
-- Create version tracking table (only needed once)
CREATE TABLE IF NOT EXISTS db_version (
  version TEXT PRIMARY KEY,
  applied_at TIMESTAMPTZ DEFAULT NOW()
);

-- Record current version (update the version number as needed)
INSERT INTO db_version (version) VALUES ('2.1')
ON CONFLICT (version) DO NOTHING;
```

To check your current version:

```sql
SELECT * FROM db_version ORDER BY applied_at DESC LIMIT 1;
```

---

## 9. Version Management & Update Workflow

This section explains how to manage updates to the app over time, whether you're making changes yourself or receiving updates from someone else.

### Understanding Version Numbers

We use **Semantic Versioning**: `MAJOR.MINOR` (e.g., 2.1)

| Type | When to Change | Example | Database Update? |
|------|----------------|---------|------------------|
| **MAJOR** (first number) | Big changes, new features, breaking changes | 1.0 → 2.0 | Usually YES |
| **MINOR** (second number) | Small fixes, tweaks, UI improvements | 2.0 → 2.1 | Sometimes |

**Rule of thumb:**
- If the MAJOR version changed → Check for database migration
- If only MINOR changed → Usually just update the HTML file

---

### Files You Need to Manage

| File | Purpose | Where It Lives |
|------|---------|----------------|
| `index.html` | The app itself | GitHub repository / Hosting |
| `DEPLOYMENT_MANUAL.md` | This manual | Keep locally + in repository |
| `CHANGELOG.md` | Record of all changes | Keep locally + in repository |
| `MIGRATION_vX.X.sql` | Database update scripts | Keep locally + in repository |
| `backup_YYYY-MM-DD.json` | Your data backups | Keep locally + cloud storage |

---

### Setting Up Version Control with GitHub (Recommended)

If you followed Section 5 and used GitHub Pages, you already have version control! Here's how to use it effectively:

#### Your Repository Structure

```
lab-slice-manager/
├── index.html              ← The app (main file)
├── README.md               ← Brief description
├── DEPLOYMENT_MANUAL.md    ← This manual
├── CHANGELOG.md            ← Version history
└── migrations/
    ├── v1.0_initial.sql    ← Original database setup
    └── v2.1_migration.sql  ← Migration from v1.0 to v2.1
```

#### How to Set This Up

1. Go to your GitHub repository
2. Click **"Add file"** → **"Create new file"**
3. Create each file listed above
4. For the `migrations/` folder, name your file `migrations/v2.1_migration.sql` (GitHub creates the folder automatically)

---

### Workflow: Making a Minor Update (e.g., 2.1 → 2.2)

**Use this for:** Bug fixes, UI tweaks, small improvements that don't change data structure.

#### Step 1: Backup Current Version
1. Download your current `index.html` from GitHub (for rollback if needed)
2. Export your data from the app (database icon → Export)

#### Step 2: Test Locally First
1. Save the new `index.html` to your computer
2. Open it in your browser
3. **Note**: Your Supabase credentials are stored in your browser, so you don't need to re-enter them!
4. Test all features work correctly
5. Verify your existing data appears correctly

#### Step 3: Update GitHub Repository
1. Go to your GitHub repository
2. Click on `index.html`
3. Click the **pencil icon** (Edit this file)
4. Select all and replace with your new code
5. In "Commit changes":
   - Write a message like: `Update to v2.2 - Fixed label printing bug`
   - Click **"Commit changes"**

#### Step 4: Update Documentation
1. Edit `CHANGELOG.md` to add the new version
2. Update `DEPLOYMENT_MANUAL.md` if needed

#### Step 5: Wait and Verify
1. Wait 1-2 minutes for GitHub Pages to rebuild
2. Hard refresh your app in browser (Ctrl+Shift+R or Cmd+Shift+R)
3. Your Supabase credentials will still be there - no need to re-enter!
4. Check the app works correctly

---

### Workflow: Making a Major Update (e.g., 2.x → 3.0)

**Use this for:** New features requiring database changes, structural changes.

#### Step 1: Full Backup (CRITICAL!)
1. Export data from the app (JSON backup)
2. Download current `index.html` from GitHub
3. Go to Supabase → Settings → Database → Create a backup (optional extra safety)

#### Step 2: Prepare Migration Files
1. Write the migration SQL (see Section 8)
2. Save it as `migrations/v3.0_migration.sql`
3. Test the migration on a copy of your data if possible

#### Step 3: Notify All Users
If others use the app:
```
Subject: Lab Slice Manager Update - Action Required

We're updating to version 3.0 on [DATE].

Before the update:
1. Please export your data (Database icon → Export)
2. Save the backup file safely

After the update:
1. You may need to log in again
2. Verify your data is intact
3. Report any issues to [CONTACT]
```

#### Step 4: Run Database Migration
1. Go to Supabase SQL Editor
2. Run the migration query
3. Verify no errors

#### Step 5: Update the App
1. Follow the Minor Update steps above
2. Update all documentation

#### Step 6: Verify Everything
1. Test all features
2. Verify data integrity
3. Test on multiple devices

---

### Creating a CHANGELOG.md

Keep a record of all changes. Create this file in your repository:

```markdown
# Changelog

All notable changes to Lab Slice Manager.

## [2.1] - 2025-01-24

### Changed
- Age display now shows months + days instead of weeks + days
- Brain region is now multi-select checkboxes (Hippocampus, Cortex)
- Default slice thickness changed to 16μm
- Protocol field now supports multiple lines

### Added
- Cryosection Date field for slices
- Embedding Matrix field (TFM/OCT) for slices
- Sort buttons for all list views
- Search function in Labels tab
- Database migration section in manual

### Removed
- Hemisphere field from slices
- Slicing Date from mice (use Sacrifice Date instead)
- Experiment Type field from experiments

### Database
- Migration required from v1.0 (see migrations/v2.1_migration.sql)

---

## [1.0] - 2025-01-20

### Added
- Initial release
- Mouse, Slice, Experiment tracking
- Label printing
- Supabase integration
- Magic link authentication
- Export/Import backup
```

---

### Quick Reference: Update Checklist

#### Before Any Update:
- [ ] Export data backup from the app
- [ ] Download current `index.html` as backup
- [ ] Read the changelog for the new version
- [ ] Check if database migration is required

#### For Minor Updates:
- [ ] Test new version locally
- [ ] Update `index.html` in GitHub
- [ ] Update `CHANGELOG.md`
- [ ] Hard refresh browser and test

#### For Major Updates:
- [ ] All "Before Any Update" items
- [ ] Notify other users
- [ ] Run database migration in Supabase
- [ ] Update `index.html` in GitHub
- [ ] Update `CHANGELOG.md`
- [ ] Update `DEPLOYMENT_MANUAL.md`
- [ ] Add migration file to `migrations/` folder
- [ ] Test all features on all devices
- [ ] Confirm with other users everything works

---

### Rolling Back if Something Goes Wrong

If an update breaks things:

#### Option 1: Rollback the Code
1. Go to GitHub repository
2. Click on `index.html`
3. Click **"History"** (clock icon)
4. Find the previous working version
5. Click on it, then click **"..."** → **"View file"**
6. Click the pencil to edit, copy all content
7. Go back to current version, paste the old content
8. Commit the change

#### Option 2: Restore from Your Backup
1. Use your downloaded backup `index.html`
2. Upload it to GitHub, replacing the broken version

#### Option 3: Restore Data
1. If data is corrupted, use the JSON backup
2. Open app in offline mode
3. Import the backup
4. This restores your data to the backup point

---

### Best Practices

1. **Always backup before updating** - This cannot be stressed enough!

2. **Test locally first** - Don't push updates directly to production

3. **Keep old versions** - Store previous `index.html` files with version numbers locally:
   ```
   old_versions/
   ├── index_v1.0.html
   ├── index_v2.0.html
   └── index_v2.1.html
   ```

4. **Document everything** - Future you will thank present you

5. **One change at a time** - Don't combine multiple big changes in one update

6. **Schedule updates** - Don't update right before important experiments

7. **Communicate** - If others use the app, give them advance notice

---

## 10. Troubleshooting

### "Supabase not configured" message

- Make sure you added your API keys correctly in Step 4
- Check that the quotes are correct: `'https://...'` not `"https://..."`
- Make sure there are no extra spaces before or after the URLs

### Magic link email not arriving

- Check your spam/junk folder
- Wait 2-3 minutes
- Try clicking "Send Magic Link" again
- Make sure you typed your email correctly

### Data not syncing

- Check if you see "Synced" or "Offline" badge in the header
- If "Offline", you're not connected to Supabase
- Try refreshing the page and logging in again

### Labels not printing correctly

- Adjust the font size smaller (try 6pt or even 4pt)
- Adjust the label width to match your actual label paper
- Use Chrome or Firefox for best print results
- Try "Print Preview" to check before printing

### Lost all my data!

1. Don't panic!
2. If you have a backup file, use Import to restore
3. If using online mode, your data should still be in Supabase
4. Try logging in again from a different browser

### Can't access the app from another computer

- Make sure you hosted the app (see Section 5)
- Use the full URL: `https://YOUR-USERNAME.github.io/lab-slice-manager`
- Make sure you're using the same email to log in

---

## Quick Reference Card

| Task | How To |
|------|--------|
| Add a mouse | Mice tab → Add Mouse |
| Add a slice | Slices tab → Add Slice → Select mouse |
| Add an experiment | Experiments tab → Add Experiment → Select slice |
| Print labels | Labels tab → Select experiments → Print |
| Backup data | Click database icon → Export |
| Restore data | Click database icon → Import |
| Change field schemas | Click settings icon → Edit fields |
| Sort data | Click sort buttons above lists |
| Filter data | Use search box or dropdown filters |

---

## Getting Help

If you encounter issues not covered in this manual:

1. Make sure you followed each step exactly
2. Try using a different web browser (Chrome is recommended)
3. Clear your browser cache and try again
4. Check that your internet connection is working

---

**Document created for Lab Slice Manager v2.2**
**Last updated: January 2025**

### Version History

| Version | Date | Changes |
|---------|------|---------|
| 2.2 | Jan 2025 | Labeling field for mice; Multiple data file paths; Field-specific search; Dynamic column order; Supabase config UI; Bug fixes |
| 2.1 | Jan 2025 | Age display changed to months+days; Added cryosection date, embedding matrix; Brain region as checkboxes; Improved label printing; Added migration section to manual |
| 1.0 | Jan 2025 | Initial release |
