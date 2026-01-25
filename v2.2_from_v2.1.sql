-- =============================================
-- Lab Slice Manager
-- MIGRATION: Version 2.1 → Version 2.2
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
-- - Adds "labeling" column to mice table
-- - Adds "dataFiles" column to experiments table (JSONB array for multiple file paths)
-- - Updates db_version to 2.2
--
-- YOUR EXISTING DATA WILL BE PRESERVED
-- =============================================

-- Step 1: Add labeling column to mice table
ALTER TABLE mice ADD COLUMN IF NOT EXISTS "labeling" TEXT;

-- Step 2: Add dataFiles column to experiments table
ALTER TABLE experiments ADD COLUMN IF NOT EXISTS "dataFiles" JSONB DEFAULT '[]'::jsonb;

-- Step 3: Update version tracking
INSERT INTO db_version (version, notes) 
VALUES ('2.2', 'Migration from v2.1: Added labeling field to mice, dataFiles (JSONB array) for multiple data file paths')
ON CONFLICT (version) DO UPDATE SET 
  applied_at = NOW(),
  notes = EXCLUDED.notes;

-- =============================================
-- MIGRATION COMPLETE!
-- 
-- Verify by running: SELECT * FROM db_version ORDER BY applied_at DESC;
-- You should see version 2.2 at the top.
--
-- The app now supports:
-- - Labeling field for mice
-- - Multiple data file paths per experiment
-- - Field-specific search in all panels
-- - Dynamic column order based on schema
-- =============================================
