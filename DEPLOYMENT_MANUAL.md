# Lab Slice Manager - Deployment Manual

## Complete Step-by-Step Guide for Non-Technical Users

**Version 3.0 | January 2025**

---

## Table of Contents

1. [Quick Start (Offline Mode)](#1-quick-start-offline-mode)
2. [Setting Up Online Mode with Supabase](#2-setting-up-online-mode-with-supabase)
3. [Creating the Database Tables](#3-creating-the-database-tables)
4. [Configuring the App](#4-configuring-the-app)
5. [Hosting Your App Online](#5-hosting-your-app-online)
6. [Using the App](#6-using-the-app)
7. [Backup and Restore](#7-backup-and-restore)
8. [Upgrading from Version 2.x](#8-upgrading-from-version-2x)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. Quick Start (Offline Mode)

If you just want to try the app right now without any setup:

### Steps:
1. **Download** the `index.html` file
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
   - **Database Password**: Create a strong password (write it down somewhere safe!)
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
-- VERSION 3.0 - January 2025
-- Many-to-Many Experiments ↔ Slices Architecture
-- Copy this ENTIRE block and run it in Supabase
-- =============================================

-- Table for storing mice
CREATE TABLE mice (
    id TEXT PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    "mouseNumber" TEXT,
    sex TEXT,
    genotype TEXT,
    labeling TEXT,
    "birthDate" DATE,
    "sacrificeDate" DATE,
    "ageMonths" INTEGER,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table for storing brain slices
CREATE TABLE slices (
    id TEXT PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    "mouseId" TEXT REFERENCES mice(id) ON DELETE CASCADE,
    region JSONB,
    thickness INTEGER,
    "cryosectionDate" DATE,
    "embeddingMatrix" TEXT DEFAULT 'TFM',
    "sliceNumber" INTEGER,
    quality TEXT,
    "storageLocation" TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table for storing experiments (independent of slices)
CREATE TABLE experiments (
    id TEXT PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT,
    "experimentDate" DATE,
    purpose TEXT,
    protocol TEXT,
    operator TEXT,
    results TEXT,
    "dataFiles" JSONB DEFAULT '[]'::jsonb,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Junction table: links experiments to slices (many-to-many)
-- Each row represents one slice in one experiment, with its own treatment
CREATE TABLE experiment_slices (
    id TEXT PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    "experimentId" TEXT REFERENCES experiments(id) ON DELETE CASCADE,
    "sliceId" TEXT REFERENCES slices(id) ON DELETE CASCADE,
    treatment TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE("experimentId", "sliceId")
);

-- Table for user settings (schemas, label config)
CREATE TABLE user_settings (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    mouse_schema JSONB,
    slice_schema JSONB,
    experiment_schema JSONB,
    experiment_slice_schema JSONB,
    label_config JSONB,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table for tracking database version
CREATE TABLE db_version (
    version TEXT PRIMARY KEY,
    applied_at TIMESTAMPTZ DEFAULT NOW(),
    notes TEXT
);

-- Record version
INSERT INTO db_version (version, notes) 
VALUES ('3.0', 'Fresh schema with many-to-many experiments-slices architecture');

-- Enable Row Level Security (keeps each user's data private)
ALTER TABLE mice ENABLE ROW LEVEL SECURITY;
ALTER TABLE slices ENABLE ROW LEVEL SECURITY;
ALTER TABLE experiments ENABLE ROW LEVEL SECURITY;
ALTER TABLE experiment_slices ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE db_version ENABLE ROW LEVEL SECURITY;

-- Security policies for mice
CREATE POLICY "Users can view own mice" ON mice FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own mice" ON mice FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own mice" ON mice FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own mice" ON mice FOR DELETE USING (auth.uid() = user_id);

-- Security policies for slices
CREATE POLICY "Users can view own slices" ON slices FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own slices" ON slices FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own slices" ON slices FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own slices" ON slices FOR DELETE USING (auth.uid() = user_id);

-- Security policies for experiments
CREATE POLICY "Users can view own experiments" ON experiments FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own experiments" ON experiments FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own experiments" ON experiments FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own experiments" ON experiments FOR DELETE USING (auth.uid() = user_id);

-- Security policies for experiment_slices
CREATE POLICY "Users can view own experiment_slices" ON experiment_slices FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own experiment_slices" ON experiment_slices FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own experiment_slices" ON experiment_slices FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own experiment_slices" ON experiment_slices FOR DELETE USING (auth.uid() = user_id);

-- Security policies for user_settings
CREATE POLICY "Users can view own settings" ON user_settings FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own settings" ON user_settings FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own settings" ON user_settings FOR UPDATE USING (auth.uid() = user_id);

-- Security policy for db_version (read-only)
CREATE POLICY "Authenticated users can view db_version" ON db_version FOR SELECT USING (auth.role() = 'authenticated');

-- Done! Your database is ready.
```

2. **Paste the code** into the SQL Editor (Ctrl+V or Cmd+V)
3. Click the **"Run"** button (or press Ctrl+Enter)
4. You should see a message saying "Success. No rows returned" - this is correct!

### Step 3.3: Verify Tables Were Created

1. Click **"Table Editor"** in the left sidebar
2. You should see 6 tables listed:
   - `mice`
   - `slices`
   - `experiments`
   - `experiment_slices`
   - `user_settings`
   - `db_version`

If you see all 6 tables, the database is ready!

---

## 4. Configuring the App

Now we need to tell the app how to connect to your Supabase database.

### Option A: Configure in the App (Recommended)

1. Open `index.html` in your browser
2. On the login screen, click **"Supabase Settings"** (or "Configure Supabase")
3. Enter your **Project URL** and **Anon Public Key** from Step 2.3
4. Click **"Save & Reload"**

**Benefits:**
- Credentials are stored in your browser's localStorage
- You don't need to edit the HTML file
- When you update the app, your credentials are preserved!

### Option B: Edit the HTML File (Alternative)

If you prefer to hardcode the credentials:

1. Open `index.html` in a text editor (Notepad, TextEdit, VS Code)
2. Find these lines near the top:
   ```javascript
   const HARDCODED_SUPABASE_URL = '';
   const HARDCODED_SUPABASE_ANON_KEY = '';
   ```
3. Add your values:
   ```javascript
   const HARDCODED_SUPABASE_URL = 'https://abcdefghij.supabase.co';
   const HARDCODED_SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIs...';
   ```
4. Save the file

---

## 5. Hosting Your App Online

To access your app from multiple devices, host it on GitHub Pages (free).

### Step 5.1: Create a GitHub Account

1. Go to **https://github.com**
2. Click **"Sign up"** and create an account

### Step 5.2: Create a Repository

1. Click the **"+"** icon in the top right → **"New repository"**
2. Repository name: `lab-slice-manager`
3. Make sure **"Public"** is selected
4. Click **"Create repository"**

### Step 5.3: Upload Your Files

1. Click **"uploading an existing file"**
2. Drag and drop your `index.html` file
3. Click **"Commit changes"**

### Step 5.4: Enable GitHub Pages

1. Go to **Settings** tab
2. Click **"Pages"** in the left sidebar
3. Under "Source", select **"main"** branch
4. Click **"Save"**
5. Wait 1-2 minutes

Your app will be available at: `https://YOUR-USERNAME.github.io/lab-slice-manager`

---

## 6. Using the App

### 6.1: Understanding the New Architecture

**Version 3.0** uses a many-to-many relationship between experiments and slices:

```
Mouse A ──► Slice 1 ──┐
                      ├──► Experiment X (comparison study)
Mouse B ──► Slice 2 ──┘

Mouse A ──► Slice 1 ──────► Experiment Y (single slice experiment)
```

- One experiment can contain multiple slices from different mice
- One slice can be part of multiple experiments
- Each slice has its own treatment/protocol within each experiment

### 6.2: Basic Workflow

#### Adding Mice
1. Go to **Mice** tab
2. Click **Add Mouse**
3. Fill in the details
4. Click **Add**

#### Adding Slices
1. Go to **Slices** tab
2. Click on a mouse button to add a slice for that mouse
3. Fill in region, thickness, etc.
4. Click **Add**

#### Creating Experiments (Two Ways)

**Method A: From Slices Tab**
1. Find a slice you want to experiment on
2. Click the flask icon (🧪)
3. Choose:
   - **Create New Experiment** - Start a new experiment with this slice
   - **Add to Existing Experiment** - Join an existing experiment
4. Enter the treatment/protocol for this specific slice

**Method B: From Experiments Tab**
1. Click **New Experiment**
2. Fill in experiment details (title, date, purpose, protocol)
3. Click **Create**
4. Expand the experiment and click **+** to add slices
5. Enter treatment for each slice

### 6.3: Printing Labels

1. Go to **Labels** tab
2. Click on experiments to select/deselect all their slices
3. Or click on individual slices within experiments
4. Click **Print** to generate labels

**Default Label Format:**
```
S-XXXX-XXXX          ← Slice ID (bold)
M001/M/7m            ← Mouse#/Sex/Age
WT/GFP+              ← Genotype/Labeling
16μm/1/30            ← Thickness/CryosectionDate
─────────────────    ← Separator
10μM Drug A          ← Treatment (per-slice)
```

### 6.4: Configuring Labels

1. In Labels tab, click **⚙️ Config**
2. The configuration panel shows **hierarchical controls**:

**Size Controls:**
- **Font Size**: 4-16pt (default 7pt)
- **Label Width**: 20-80mm (default 38mm)

**Line Configuration (hierarchical):**

| Line | Group Toggle | Individual Fields |
|------|--------------|-------------------|
| Line 1 | Slice ID | (single field) |
| Line 2 | Mouse Basic | Mouse Number, Sex, Age |
| Line 3 | Mouse Details | Genotype, Labeling |
| Line 4 | Slice Info | Region (off by default), Thickness, Cryo Date |
| Line 5 | Treatment | (with dashed separator) |

**How it works:**
- Toggle a **group** to show/hide the entire line
- When a group is enabled, toggle **individual fields** within it
- Fields within a line are joined with `/` (no spaces)

---

## 7. Backup and Restore

### Exporting Data (Backup)

1. Click the **database icon** (📁) in the header
2. Click **Export Data**
3. Save the JSON file somewhere safe

### Importing Data (Restore)

1. Click the **database icon** (📁) in the header
2. Click **Import**
3. Select your backup JSON file

**Tip**: Make regular backups, especially before making changes or updating the app!

---

## 8. Upgrading from Version 2.x

⚠️ **Version 3.0 requires a fresh database schema.** Migration is not possible due to the fundamental architecture change.

### Before You Start

1. **Export your v2.x data** (Database icon → Export)
2. Save the backup file safely
3. Note your mice and slices - these can be re-imported
4. Experiments will need to be re-created manually

### Upgrade Steps

#### Step 1: Drop Old Tables (Supabase SQL Editor)

```sql
-- WARNING: This deletes all data!
DROP TABLE IF EXISTS experiments CASCADE;
DROP TABLE IF EXISTS slices CASCADE;
DROP TABLE IF EXISTS mice CASCADE;
DROP TABLE IF EXISTS user_settings CASCADE;
DROP TABLE IF EXISTS db_version CASCADE;
```

#### Step 2: Run Fresh Schema

Copy and run the SQL from Section 3.2 above.

#### Step 3: Update the App

Replace your `index.html` with the v3.0 version.

#### Step 4: Re-enter Data

Option A: Manually re-enter everything
Option B: Partially import from backup:
1. Open v3.0 in offline mode
2. Import your v2.x backup file
3. Mice and slices will be restored
4. Re-create experiments with the new multi-slice structure

---

## 9. Troubleshooting

### "Supabase not configured" message

- Click "Supabase Settings" on the login screen
- Enter your Project URL and Anon Key
- Click "Save & Reload"

### Magic link email not arriving

- Check your spam/junk folder
- Wait 2-3 minutes
- Try clicking "Send Magic Link" again
- Make sure you typed your email correctly

### Data not syncing

- Refresh the page and log in again
- Check your internet connection
- If using institutional network, you may need IT to whitelist `*.supabase.co`

### Labels not printing correctly

- Adjust font size smaller (try 6pt or 4pt)
- Adjust label width to match your label paper
- Use Chrome or Firefox for best results
- Use Print Preview to check before printing

### "Cannot delete" error

- Mice: Delete all their slices first
- Slices: Remove from all experiments first
- Experiments: Will also remove all slice links (with confirmation)

### Lost all my data!

1. Don't panic!
2. If you have a backup file, use Import to restore
3. If using online mode, your data should still be in Supabase
4. Try logging in from a different browser

---

## Quick Reference Card

| Task | How To |
|------|--------|
| Add a mouse | Mice tab → Add Mouse |
| Add a slice | Slices tab → Click mouse button |
| Create experiment | Experiments tab → New Experiment |
| Add slice to experiment | Slices tab → Flask icon, OR Experiments tab → Expand → + button |
| Edit slice treatment | Experiments tab → Expand → Pencil icon on slice |
| Print labels | Labels tab → Select experiments/slices → Print |
| Backup data | Database icon → Export |
| Restore data | Database icon → Import |
| Change schemas | Settings icon → Select category → Edit fields |

---

**Document created for Lab Slice Manager v3.0**
**Last updated: January 2025**

### Version History

| Version | Date | Changes |
|---------|------|---------|
| 3.0 | Jan 2025 | Many-to-many experiments/slices; Per-slice treatments; Complete architecture redesign |
| 2.3 | Jan 2025 | Bug fixes for sex field optionality; RLS policy for db_version |
| 2.2 | Jan 2025 | Labeling field; Multiple data files; Supabase config UI |
| 2.1 | Jan 2025 | Age display; Cryosection date; Embedding matrix; Region checkboxes |
| 1.0 | Jan 2025 | Initial release |
