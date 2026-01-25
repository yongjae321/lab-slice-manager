# Changelog

All notable changes to Lab Slice Manager will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

---

## [2.2] - 2025-01-24

### Added
- **Labeling Field**: New "Labeling" field for mice (appears as column in table)
- **Multiple Data File Paths**: Experiments now support adding multiple data file paths as a list (add/remove individual paths)
- **Field-Specific Search**: All panels (Mice, Slices, Experiments, Labels) now have a dropdown to select which field to search in
- **Supabase Configuration UI**: Enter Supabase credentials directly in the app (no need to edit HTML file)
- New field type "Multiple Paths/Lines" available in schema editor

### Changed
- **Dynamic Column Order**: Table/card columns now follow schema order - reorder fields in Settings → Schema to change display order
- Search now defaults to "All Fields" but can be narrowed to specific fields
- Experiment display now shows Data Files and Protocol as separate sections
- Slices and Experiments search can filter by mouse-related fields (Mouse Number, Sex, Genotype)
- Labels search can filter by slice-related fields as well
- Supabase credentials now stored in browser localStorage (survives file updates)

### Fixed
- **Magic link redirect**: Fixed redirect URL to include full path (fixes GitHub Pages subpath deployments)
- **Data not saving**: Added error handling - shows alert if Supabase save fails, data still saved locally
- **Data disappearing on refresh**: Fixed loading logic that could overwrite local data with empty Supabase results
- **Silent failures**: All Supabase errors now logged to browser console for debugging

### Database Changes
- **Migration required from v2.1** (if using Supabase)
- New column: `dataFiles` (JSONB array) in experiments table
- See `migrations/v2.2_from_v2.1.sql`

---

## [2.1] - 2025-01-24

### Changed
- Age display now shows **months + days** instead of weeks + days (e.g., "3m 15d (105d)")
- Brain region is now **multi-select checkboxes** (Hippocampus, Cortex) instead of dropdown
- Default slice thickness changed from 300μm to **16μm**
- Protocol field now supports **multiple lines** of text
- Mouse sex now displayed next to mouse number in Slices and Experiments tabs

### Added
- **Cryosection Date** field for slices
- **Embedding Matrix** field (TFM/OCT, default TFM) for slices
- **Sort buttons** for all list views (Mice, Slices, Experiments, Labels)
- **Search function** in Labels tab
- **Database Updates & Migration** section in manual (Section 8)
- **Version Management & Update Workflow** section in manual (Section 9)
- `db_version` table for tracking database version
- Version history table in manual

### Removed
- Hemisphere field from slices
- Slicing Date from mice (use Sacrifice Date instead)
- Experiment Type field from experiments

### Fixed
- Label text now wraps properly instead of overflowing the box
- Font size can now be set to non-integer values (minimum 4pt)
- Label width can now be set to non-integer values

### Database Changes
- **Migration required from v1.0**
- See `migrations/v2.1_from_v1.0.sql`
- New columns: `cryosectionDate`, `embeddingMatrix`
- Changed column: `region` (TEXT → JSONB for multi-select)

---

## [1.0] - 2025-01-20

### Added
- Initial release
- **Mouse tracking**: ID, number, sex, genotype, birth date, sacrifice date, notes
- **Slice tracking**: Linked to mouse, region, thickness, quality, storage location, notes
- **Experiment tracking**: Linked to slice, date, protocol, operator, results, notes
- **Label printing**: Customizable font size, label width, field selection
- **Supabase integration**: Cloud sync with magic link / OTP authentication
- **Offline mode**: Full functionality without internet
- **Export/Import**: JSON backup for data portability
- **Editable schemas**: Add/remove/rename fields for each entity
- **Search and filter**: Find records across all fields

### Database
- Initial schema with 4 tables: `mice`, `slices`, `experiments`, `user_settings`

---

## How to Use This Changelog

### When Updating

1. Add a new section at the top with the version number and date
2. Group changes under these categories:
   - **Added** - New features
   - **Changed** - Changes to existing features
   - **Removed** - Removed features
   - **Fixed** - Bug fixes
   - **Database Changes** - Any schema changes requiring migration

### Version Numbers

- **MAJOR.MINOR** format (e.g., 2.1)
- Increment MAJOR for breaking changes or major new features
- Increment MINOR for small improvements, bug fixes, UI tweaks

### Example Entry

```markdown
## [2.2] - 2025-02-15

### Added
- Export to CSV feature

### Fixed
- Sorting now works correctly with empty values

### Database Changes
- None (no migration required)
```
