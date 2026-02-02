-- =============================================
-- Lab Slice Manager
-- FRESH SCHEMA - Version 3.1
-- Architecture: Many-to-Many Experiments ↔ Slices (duplicates allowed)
-- Date: January 2025
-- =============================================
--
-- INSTRUCTIONS:
-- 1. Go to Supabase → SQL Editor
-- 2. Click "New query"
-- 3. Copy and paste this entire file
-- 4. Click "Run"
-- 5. Verify no errors appear
--
-- WARNING: This will DROP existing tables!
-- Make sure you've backed up any data you want to keep.
-- =============================================

-- Drop existing tables (order matters due to foreign keys)
DROP TABLE IF EXISTS experiment_slices CASCADE;
DROP TABLE IF EXISTS experiments CASCADE;
DROP TABLE IF EXISTS slices CASCADE;
DROP TABLE IF EXISTS mice CASCADE;
DROP TABLE IF EXISTS user_settings CASCADE;
DROP TABLE IF EXISTS db_version CASCADE;

-- =============================================
-- TABLE: mice
-- Stores mouse information
-- =============================================
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

-- Enable RLS
ALTER TABLE mice ENABLE ROW LEVEL SECURITY;

-- RLS Policies for mice
CREATE POLICY "Users can view own mice" ON mice
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own mice" ON mice
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own mice" ON mice
    FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own mice" ON mice
    FOR DELETE USING (auth.uid() = user_id);

-- =============================================
-- TABLE: slices
-- Stores brain slice information, linked to mice
-- =============================================
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

-- Enable RLS
ALTER TABLE slices ENABLE ROW LEVEL SECURITY;

-- RLS Policies for slices
CREATE POLICY "Users can view own slices" ON slices
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own slices" ON slices
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own slices" ON slices
    FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own slices" ON slices
    FOR DELETE USING (auth.uid() = user_id);

-- =============================================
-- TABLE: experiments
-- Stores experiment-level information (independent of slices)
-- =============================================
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

-- Enable RLS
ALTER TABLE experiments ENABLE ROW LEVEL SECURITY;

-- RLS Policies for experiments
CREATE POLICY "Users can view own experiments" ON experiments
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own experiments" ON experiments
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own experiments" ON experiments
    FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own experiments" ON experiments
    FOR DELETE USING (auth.uid() = user_id);

-- =============================================
-- TABLE: experiment_slices (Junction Table)
-- Links experiments to slices (many-to-many)
-- Contains per-slice treatment information
-- NOTE: Same slice can appear multiple times in the same experiment
--       (each with its own treatment/notes)
-- =============================================
CREATE TABLE experiment_slices (
    id TEXT PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    "experimentId" TEXT REFERENCES experiments(id) ON DELETE CASCADE,
    "sliceId" TEXT REFERENCES slices(id) ON DELETE CASCADE,
    treatment TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE experiment_slices ENABLE ROW LEVEL SECURITY;

-- RLS Policies for experiment_slices
CREATE POLICY "Users can view own experiment_slices" ON experiment_slices
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own experiment_slices" ON experiment_slices
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own experiment_slices" ON experiment_slices
    FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own experiment_slices" ON experiment_slices
    FOR DELETE USING (auth.uid() = user_id);

-- =============================================
-- TABLE: user_settings
-- Stores user preferences, schemas, label config
-- =============================================
CREATE TABLE user_settings (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    mouse_schema JSONB,
    slice_schema JSONB,
    experiment_schema JSONB,
    experiment_slice_schema JSONB,
    label_config JSONB,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;

-- RLS Policies for user_settings
CREATE POLICY "Users can view own settings" ON user_settings
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own settings" ON user_settings
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own settings" ON user_settings
    FOR UPDATE USING (auth.uid() = user_id);

-- =============================================
-- TABLE: db_version
-- Tracks database version for migrations
-- =============================================
CREATE TABLE db_version (
    version TEXT PRIMARY KEY,
    applied_at TIMESTAMPTZ DEFAULT NOW(),
    notes TEXT
);

-- Enable RLS (read-only for authenticated users)
ALTER TABLE db_version ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view db_version" ON db_version
    FOR SELECT USING (auth.role() = 'authenticated');

-- Record version
INSERT INTO db_version (version, notes) 
VALUES ('3.1', 'Fresh schema with many-to-many experiments-slices, duplicate slices allowed per experiment');

-- =============================================
-- SCHEMA COMPLETE!
-- 
-- Verify by running: SELECT * FROM db_version;
-- You should see version 3.1 listed.
-- =============================================
