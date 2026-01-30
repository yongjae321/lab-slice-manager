# Changelog

All notable changes to Lab Slice Manager.

---

## [3.0] - 2025-01-30

### 🚨 Breaking Changes
- **Complete architecture redesign** - Fresh database required
- Old v2.x data must be exported and manually re-entered
- Experiments no longer belong to a single slice

### Changed
- **Many-to-Many Experiments**: Experiments can now contain multiple slices from different mice
- **Per-Slice Treatments**: Each slice within an experiment has its own treatment/protocol field
- **Independent Experiments**: Create experiments first, then add slices (or vice versa)
- **Labels Tab Redesign**: Select experiments, then select individual slices within for printing
- **New Label Layout**: 
  - Line 1: Slice ID (bold)
  - Line 2: MouseNumber/Sex/Age
  - Line 3: Genotype/Labeling  
  - Line 4: Thickness/CryoDate (region OFF by default)
  - Line 5: Treatment (with separator)
- **Hierarchical Label Config**: Group-level toggles + individual field toggles

### Added
- `experiment_slices` junction table linking experiments to slices
- "Add to Experiment" modal with two options:
  - Create new experiment with this slice
  - Add to existing experiment
- Experiment expansion view showing all linked slices with treatments
- Per-slice treatment editing within experiments
- Settings panel now includes "Per-Slice" schema tab

### Removed
- `sliceId` foreign key from experiments table (replaced by junction table)
- Old label printing flow (was based on single slice per experiment)

### Database
- **Fresh schema required** - Run `fresh_schema_v3.sql`
- New tables: `experiment_slices` (junction table)
- Modified: `experiments` (removed sliceId, added title, purpose, operator fields)

---

## [2.3] - 2025-01-28

### Fixed
- Sex field now properly optional (browser no longer requires selection)
- `mergeSchemas` function now syncs `required` property from defaults

### Security
- Added RLS policy to `db_version` table (read-only for authenticated users)

---

## [2.2] - 2025-01-26

### Added
- Labeling field for mice
- Multiple data file paths for experiments (multitext field type)
- Field-specific search dropdowns in all tabs
- Supabase configuration UI in login screen
- Dynamic column ordering based on schema

### Changed
- Supabase credentials can now be entered in the app (stored in localStorage)
- Improved search to work on specific fields

### Fixed
- Various bug fixes for edge cases

---

## [2.1] - 2025-01-24

### Changed
- Age display now shows months + days instead of weeks + days
- Brain region is now multi-select checkboxes (H, C)
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
- Migration required from v1.0 (see `migrations/v2.1_from_v1.0.sql`)

---

## [1.0] - 2025-01-20

### Added
- Initial release
- Mouse, Slice, Experiment tracking
- Label printing
- Supabase integration
- Magic link authentication
- Export/Import backup
- Dynamic schema editor
- Offline mode support
