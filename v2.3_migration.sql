-- Migration for Lab Slice Manager v2.3
-- Run this in Supabase SQL Editor

-- Add title column to experiments table
ALTER TABLE experiments ADD COLUMN IF NOT EXISTS "title" TEXT;

-- Add manual age column to mice table
ALTER TABLE mice ADD COLUMN IF NOT EXISTS "ageMonths" INTEGER;

-- Ensure all required columns exist
ALTER TABLE mice ADD COLUMN IF NOT EXISTS "labeling" TEXT;
ALTER TABLE experiments ADD COLUMN IF NOT EXISTS "dataFiles" JSONB DEFAULT '[]'::jsonb;

-- Verify RLS policies are correct for experiments table
-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view own experiments" ON experiments;
DROP POLICY IF EXISTS "Users can insert own experiments" ON experiments;
DROP POLICY IF EXISTS "Users can update own experiments" ON experiments;
DROP POLICY IF EXISTS "Users can delete own experiments" ON experiments;

-- Recreate RLS policies
CREATE POLICY "Users can view own experiments" ON experiments
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own experiments" ON experiments
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own experiments" ON experiments
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own experiments" ON experiments
    FOR DELETE USING (auth.uid() = user_id);

-- Enable RLS on experiments table (if not already enabled)
ALTER TABLE experiments ENABLE ROW LEVEL SECURITY;
