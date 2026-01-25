-- =============================================
-- Lab Slice Manager
-- MIGRATION: Version 1.0 → Version 2.1
-- Date: January 2025
-- =============================================
--
-- INSTRUCTIONS:
-- 1. BACKUP YOUR DATA FIRST! (App → Database icon → Export)
-- 2. Go to Supabase → SQL Editor
-- 3. Click "New query"
-- 4. Copy and paste this entire file
-- 5. Click "Run"
-- 6. Verify no errors appear
-- 7. Test the app
--
-- WHAT THIS MIGRATION DOES:
-- - Adds "cryosectionDate" column to slices
-- - Adds "embeddingMatrix" column to slices (default: TFM)
-- - Converts "region" from TEXT to JSONB (for multi-select checkboxes)
-- - Creates db_version table to track database version
-- - Records version 2.1
--
-- YOUR EXISTING DATA WILL BE PRESERVED
-- =============================================

-- Step 1: Add new columns to slices table
ALTER TABLE slices ADD COLUMN IF NOT EXISTS "cryosectionDate" DATE;
ALTER TABLE slices ADD COLUMN IF NOT EXISTS "embeddingMatrix" TEXT DEFAULT 'TFM';

-- Step 2: Convert region column from TEXT to JSONB
-- This safely converts existing text values to JSON arrays
DO $$ 
BEGIN
  -- Check if region column exists and is TEXT (not already JSONB)
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'slices' 
    AND column_name = 'region' 
    AND data_type = 'text'
  ) THEN
    -- Create temporary column
    ALTER TABLE slices ADD COLUMN region_new JSONB;
    
    -- Migrate existing data: convert text to JSON array
    UPDATE slices SET region_new = 
      CASE 
        WHEN region IS NULL THEN NULL
        WHEN region = '' THEN NULL
        WHEN region LIKE '[%' THEN region::JSONB  -- Already JSON format
        ELSE jsonb_build_array(region)            -- Convert single text to array
      END;
    
    -- Drop old column and rename new one
    ALTER TABLE slices DROP COLUMN region;
    ALTER TABLE slices RENAME COLUMN region_new TO region;
    
    RAISE NOTICE 'Successfully converted region column to JSONB';
  ELSE
    RAISE NOTICE 'Region column is already JSONB or does not exist - skipping conversion';
  END IF;
END $$;

-- Step 3: Create version tracking table (if it doesn't exist)
CREATE TABLE IF NOT EXISTS db_version (
  version TEXT PRIMARY KEY,
  applied_at TIMESTAMPTZ DEFAULT NOW(),
  notes TEXT
);

-- Step 4: Record this migration
INSERT INTO db_version (version, notes) 
VALUES ('2.1', 'Migration from v1.0: Added cryosectionDate, embeddingMatrix; Converted region to JSONB')
ON CONFLICT (version) DO UPDATE SET 
  applied_at = NOW(),
  notes = EXCLUDED.notes;

-- =============================================
-- MIGRATION COMPLETE!
-- 
-- Verify by running: SELECT * FROM db_version;
-- You should see version 2.1 listed.
--
-- If you see any errors above, DO NOT use the app yet.
-- Instead, restore from your backup and seek help.
-- =============================================
