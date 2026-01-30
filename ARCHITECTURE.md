# Lab Slice Manager: Architecture Deep Dive

*A story of building a full-stack web app in a single HTML file*

**Version 3.0 | January 2025**

---

## Table of Contents
1. [The Big Picture](#the-big-picture)
2. [Architecture Overview](#architecture-overview)
3. [The Technology Stack](#the-technology-stack)
4. [Data Model: Many-to-Many](#data-model-many-to-many)
5. [The Database Layer](#the-database-layer)
6. [Authentication: Magic Links](#authentication-magic-links)
7. [The Offline-First Philosophy](#the-offline-first-philosophy)
8. [Dynamic Schemas](#dynamic-schemas)
9. [Label Printing System](#label-printing-system)
10. [Bugs We Encountered](#bugs-we-encountered)
11. [Lessons Learned](#lessons-learned)

---

## The Big Picture

Imagine you're a neuroscience researcher. You have mice, you slice their brains, you run experiments on those slices, and you need to print tiny labels to track everything. 

**The v2.x limitation**: Each experiment belonged to exactly one slice. But real research often involves comparing slices from different mice in the same experiment.

**The v3.0 solution**: A many-to-many relationship where experiments can contain multiple slices, and each slice can have its own treatment protocol within that experiment.

This project is a **Progressive Web App (PWA)** that runs entirely from a single HTML file, syncs to the cloud, works offline, and prints labels for your tissue samples.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        SINGLE HTML FILE                         │
│  ┌───────────────┬───────────────┬───────────────────────────┐  │
│  │    React 18   │   Tailwind    │      Application Code     │  │
│  │   (via CDN)   │   (via CDN)   │   (Components, Logic)     │  │
│  └───────────────┴───────────────┴───────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ HTTPS API Calls
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         SUPABASE                                │
│  ┌───────────────┬───────────────┬───────────────────────────┐  │
│  │     Auth      │   PostgreSQL  │   Row Level Security      │  │
│  │ (Magic Links) │   (6 Tables)  │      (RLS Policies)       │  │
│  └───────────────┴───────────────┴───────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ Fallback
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      LOCAL STORAGE                              │
│         (Offline data, cached schemas, Supabase config)         │
└─────────────────────────────────────────────────────────────────┘
```

### The "No Build Step" Philosophy

We load React and Babel directly from CDNs, and the browser compiles our JSX on the fly. This means:

- No `npm install`
- No Webpack/Vite configuration
- No build step
- Just open the file and it works

**Trade-off**: Slightly slower initial load (~100ms) for massively simpler development and deployment.

---

## The Technology Stack

### Frontend: React 18 via CDN

```html
<script src="https://unpkg.com/react@18/umd/react.production.min.js"></script>
<script src="https://unpkg.com/react-dom@18/umd/react-dom.production.min.js"></script>
<script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>
```

### Styling: Tailwind CSS

```html
<script src="https://cdn.tailwindcss.com"></script>
```

One line. No configuration. Utility-first styling.

### Backend: Supabase

- **PostgreSQL** database with proper relational structure
- **Magic Link authentication** (no passwords)
- **Row Level Security** for multi-user data isolation
- **Free tier** sufficient for lab use

### Icons: Lucide

```jsx
const Icon = ({ name, className }) => {
  const iconRef = useRef(null);
  useEffect(() => {
    if (iconRef.current && lucide.icons[name]) {
      iconRef.current.innerHTML = '';
      iconRef.current.appendChild(lucide.createElement(lucide.icons[name]));
    }
  }, [name]);
  return <span ref={iconRef} className={className} />;
};
```

---

## Data Model: Many-to-Many

### The v2.x Problem

```
Mouse → Slice → Experiment
         1:1 relationship
```

This meant:
- Each experiment could only study one slice
- Comparison studies required creating separate experiments
- No way to track which slices were compared together

### The v3.0 Solution

```
┌──────────┐      ┌──────────┐
│   MICE   │      │  SLICES  │
│          │──1:N─│          │
│ M-XXXX   │      │ S-XXXX   │
└──────────┘      └────┬─────┘
                       │
                       │ N:M (via junction table)
                       │
┌──────────────────────┼──────────────────────┐
│                      │                      │
│         ┌────────────┴────────────┐         │
│         │   EXPERIMENT_SLICES     │         │
│         │     (junction table)    │         │
│         │                         │         │
│         │ - experimentId (FK)     │         │
│         │ - sliceId (FK)          │         │
│         │ - treatment (per-slice) │         │
│         │ - notes (per-slice)     │         │
│         └────────────┬────────────┘         │
│                      │                      │
└──────────────────────┼──────────────────────┘
                       │
                ┌──────┴──────┐
                │ EXPERIMENTS │
                │             │
                │ E-XXXX      │
                │ (independent)│
                └─────────────┘
```

### Key Design Decisions

**1. Experiments are independent entities**
- Not subordinate to any single slice
- Have their own fields: title, purpose, protocol, operator, results
- Can exist without any slices (empty experiment)

**2. Per-slice treatment in junction table**
- Each slice in an experiment has its own `treatment` field
- This is where you record: "10μM Drug A", "Control", "Vehicle only", etc.
- Enables comparison studies within a single experiment

**3. Cascade deletes with protection**
- Deleting an experiment removes all `experiment_slices` links
- Deleting a slice requires first removing it from all experiments
- Deleting a mouse requires first deleting all its slices

---

## The Database Layer

### Tables Overview

```sql
-- Core data tables
mice                 -- Animal subjects
slices               -- Brain tissue sections
experiments          -- Research activities
experiment_slices    -- Junction: many-to-many link with per-slice data

-- System tables
user_settings        -- Schemas, label config
db_version           -- Migration tracking
```

### Schema Details

#### mice
```sql
CREATE TABLE mice (
    id TEXT PRIMARY KEY,           -- e.g., "M-LXK8-F3A2"
    user_id UUID,                  -- Owner (for RLS)
    "mouseNumber" TEXT,            -- Lab identifier
    sex TEXT,                      -- M/F
    genotype TEXT,                 -- e.g., "WT", "APP/PS1"
    labeling TEXT,                 -- e.g., "GFP+", "tdTomato"
    "birthDate" DATE,
    "sacrificeDate" DATE,
    "ageMonths" INTEGER,           -- Manual age if no birthDate
    notes TEXT,
    created_at TIMESTAMPTZ
);
```

#### slices
```sql
CREATE TABLE slices (
    id TEXT PRIMARY KEY,           -- e.g., "S-ABK2-N7P4"
    user_id UUID,
    "mouseId" TEXT REFERENCES mice(id) ON DELETE CASCADE,
    region JSONB,                  -- ["H", "C"] for multi-select
    thickness INTEGER,             -- μm
    "cryosectionDate" DATE,
    "embeddingMatrix" TEXT,        -- TFM, OCT
    "sliceNumber" INTEGER,
    quality TEXT,
    "storageLocation" TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ
);
```

#### experiments
```sql
CREATE TABLE experiments (
    id TEXT PRIMARY KEY,           -- e.g., "E-QWE4-R5TY"
    user_id UUID,
    title TEXT,                    -- "Drug A Dose Response"
    "experimentDate" DATE,
    purpose TEXT,                  -- Multi-line
    protocol TEXT,                 -- Experiment-level protocol
    operator TEXT,                 -- Who ran the experiment
    results TEXT,
    "dataFiles" JSONB,             -- Array of file paths
    notes TEXT,
    created_at TIMESTAMPTZ
);
```

#### experiment_slices (Junction Table)
```sql
CREATE TABLE experiment_slices (
    id TEXT PRIMARY KEY,           -- e.g., "ES-MNB3-V8CX"
    user_id UUID,
    "experimentId" TEXT REFERENCES experiments(id) ON DELETE CASCADE,
    "sliceId" TEXT REFERENCES slices(id) ON DELETE CASCADE,
    treatment TEXT,                -- Per-slice: "10μM Drug A"
    notes TEXT,                    -- Per-slice notes
    created_at TIMESTAMPTZ,
    UNIQUE("experimentId", "sliceId")  -- No duplicates
);
```

### Row Level Security (RLS)

Every table has RLS enabled with policies like:

```sql
CREATE POLICY "Users can view own mice" ON mice
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own mice" ON mice
    FOR INSERT WITH CHECK (auth.uid() = user_id);
```

**Why this matters**: The Supabase `anon` key is public. Without RLS, anyone with the key could read/write all data. With RLS, users can only access their own records.

---

## Authentication: Magic Links

### Flow

1. User enters email
2. Supabase sends email with link/code
3. User clicks link OR enters 6-digit code
4. Session created, user logged in

### Implementation

```jsx
// Send magic link
const { error } = await supabase.auth.signInWithOtp({
  email: email,
  options: {
    emailRedirectTo: window.location.href.split('?')[0]
  }
});

// Verify OTP code
const { error } = await supabase.auth.verifyOtp({
  email: email,
  token: otp,
  type: 'email'
});
```

### Why Magic Links?

- No passwords to remember
- No passwords to leak
- No password reset flow
- Works on any device with email access

---

## The Offline-First Philosophy

### Dual Storage Strategy

Every data change is saved to both:
1. **React state** (immediate UI update)
2. **localStorage** (local backup)
3. **Supabase** (cloud sync, if online)

```jsx
// 1. Update React state immediately (optimistic UI)
setMice([newMouse, ...mice]);

// 2. localStorage sync happens via useEffect
useEffect(() => {
  if (dataLoaded) {
    localStorage.setItem('labManager_mice', JSON.stringify(mice));
  }
}, [mice]);

// 3. Supabase sync
if (supabase && user && !user.offline) {
  const { error } = await supabase.from('mice').insert({ ...newMouse, user_id: user.id });
  if (error) alert('Cloud error. Data saved locally.');
}
```

### Offline Mode

Users can click "Continue Offline" to use the app without cloud:

```jsx
const offlineUser = { offline: true, id: 'offline-user' };
setUser(offlineUser);
```

The app works identically, just without sync. Export/Import handles data transfer.

---

## Dynamic Schemas

### Problem
Different labs need different fields. Hardcoding fields means constant code changes.

### Solution
Fields are defined in schema arrays:

```jsx
const DEFAULT_MOUSE_SCHEMA = [
  { key: 'mouseNumber', label: 'Mouse Number', type: 'text', required: true },
  { key: 'sex', label: 'Sex', type: 'select', options: ['M', 'F'], required: false },
  { key: 'genotype', label: 'Genotype', type: 'text', required: false },
  // ...
];
```

The `DynamicForm` component renders inputs based on schema:

```jsx
{schema.map(field => {
  if (field.type === 'text') return <input type="text" ... />;
  if (field.type === 'select') return <select ... />;
  if (field.type === 'multicheck') return <CheckboxGroup ... />;
  if (field.type === 'textarea') return <textarea ... />;
  // ...
})}
```

### Schema Migration

When defaults change, `mergeSchemas` reconciles old cached schemas with new defaults:

```jsx
const mergeSchemas = (defaultSchema, savedSchema) => {
  const defaultByKey = {};
  defaultSchema.forEach(f => { defaultByKey[f.key] = f; });
  
  const savedKeys = new Set(savedSchema.map(f => f.key));
  const newFields = defaultSchema.filter(f => !savedKeys.has(f.key));
  
  // Sync required property from defaults
  const updatedSaved = savedSchema.map(f => {
    if (defaultByKey[f.key]) {
      return { ...f, required: defaultByKey[f.key].required };
    }
    return f;
  });
  
  return [...newFields, ...updatedSaved];
};
```

---

## Label Printing System

### Design Goals

1. **Compact**: Fit on small dish lids
2. **Readable**: Essential info at a glance
3. **No Field Names**: Just values (saves space)
4. **Consistent Format**: `value/value/value` style (no spaces)
5. **Hierarchical Config**: Group-level and field-level toggles

### Default Label Layout

```
E-XXXX-XXXX              ← Experiment ID (optional, off by default)
S-XXXX-XXXX              ← Slice ID (bold)
M001/M/7m                ← Mouse#/Sex/Age
WT/GFP+                  ← Genotype/Labeling
16μm/1/30                ← Thickness/CryoDate (region OFF by default)
─────────────────        ← Dashed separator
10μM Drug A              ← Treatment (from junction table)
```

### Hierarchical Configuration

```javascript
const DEFAULT_LABEL_CONFIG = {
  fontSize: 7,
  labelWidth: 38,
  labelPadding: 1.0,    // mm, adjustable 0-3mm
  
  // Experiment ID (optional, off by default)
  showExpId: false,
  
  // Line 1: Slice ID
  showSliceId: true,
  
  // Line 2: Mouse basic (group)
  showMouseBasic: true,
  showMouseNumber: true,
  showSex: true,
  showAge: true,
  
  // Line 3: Mouse details (group)
  showMouseDetails: true,
  showGenotype: true,
  showLabeling: true,
  
  // Line 4: Slice info (group)
  showSliceInfo: true,
  showRegion: false,      // OFF by default
  showThickness: true,
  showCryoDate: true,
  
  // Line 5: Treatment (with separator)
  showTreatment: true,
};
```

The configuration UI provides:
- **Size controls**: Font size (4-16pt), label width (20-80mm), padding (0-3mm)
- **Group toggles**: Enable/disable entire lines
- **Field toggles**: Fine-tune which fields appear within a line
- Group checkbox shows indeterminate state when some but not all children are enabled

### Implementation

```jsx
const printLabels = () => {
  const w = window.open('', '_blank');
  w.document.write(`
    <style>
      body { font-family: 'Courier New', monospace; font-size: ${fontSize}pt; }
      .label { border: 0.5pt solid #000; padding: 1.5mm; width: ${width}mm; }
      .treatment { border-top: 0.4pt dashed #666; margin-top: 0.8mm; }
    </style>
    <body>
      ${labelData.map(({ exp, slice, mouse, treatment }) => `
        <div class="label">
          <div class="id">${exp.id}</div>
          <div>${mouse.mouseNumber}/${abbrevSex(mouse.sex)}/${age}/${mouse.genotype}</div>
          <div>${abbrevRegion(slice.region)}/${slice.thickness}μm</div>
          ${treatment ? `<div class="treatment">${treatment}</div>` : ''}
        </div>
      `).join('')}
    </body>
  `);
  w.print();
};
```

### Selection System

Labels tab uses a two-level selection:
1. **Experiment level**: Click to select/deselect all slices in experiment
2. **Slice level**: Click individual slices to fine-tune selection

```jsx
// State: Map<experimentId, Set<experimentSliceId>>
const [selectedItems, setSelectedItems] = useState(new Map());

// Toggle experiment (all slices)
const toggleExp = (expId, allSliceIds) => {
  const newSelected = new Map(selectedItems);
  if (newSelected.has(expId)) {
    newSelected.delete(expId);
  } else {
    newSelected.set(expId, new Set(allSliceIds));
  }
  setSelectedItems(newSelected);
};

// Toggle individual slice
const toggleSlice = (expId, sliceId) => {
  // Add/remove slice from experiment's set
  // ...
};
```

---

## Bugs We Encountered

### Bug #1: Sex Field Still Required After Making Optional

**Symptom**: Changed schema to `required: false`, but browser still showed validation error.

**Root cause**: Old schema with `required: true` was cached in localStorage.

**Fix**: Updated `mergeSchemas` to sync `required` property from defaults.

### Bug #2: Template Literal Functions in document.write()

**Symptom**: Labels printed "undefined" instead of "M" or "F".

**Root cause**: Functions like `abbrevSex()` inside template strings passed to `document.write()` couldn't access local scope.

**Fix**: Pre-compute values before the template:
```jsx
const sexAbbrev = abbrevSex(mouse?.sex);  // Compute first
// Later in template:
`<div>${sexAbbrev}</div>`
```

### Bug #3: RLS on db_version Table

**Symptom**: Supabase warning about public access to `db_version` table.

**Fix**: Added read-only RLS policy:
```sql
ALTER TABLE db_version ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view db_version" ON db_version
    FOR SELECT USING (auth.role() = 'authenticated');
```

### Bug #4: Integer Field Empty String

**Symptom**: "Invalid input syntax for type integer" when saving form with empty number field.

**Fix**: Convert empty strings to null:
```jsx
if (field.type === 'number') {
  cleanedData[key] = form[key] === '' ? null : Number(form[key]);
}
```

---

## Lessons Learned

### 1. Start Simple, Add Complexity When Needed
Single HTML file. No build system. Iterate fast.

### 2. Optimistic UI with Graceful Degradation
Update UI immediately. Save to cloud in background. Handle failures gracefully.

### 3. Security Through Architecture
RLS makes public API keys safe. Security lives in the database, not the code.

### 4. Schema Evolution is Hard
When you have cached configuration, you need migration logic.

### 5. Dates Are Always Complicated
Use a date library for anything non-trivial.

### 6. Human-Readable IDs Matter
`M-LXK8-F3A2` beats `550e8400-e29b-41d4-a716-446655440000` for lab work.

---

## What's Next?

Potential future improvements:
- **TypeScript**: Better type safety as codebase grows
- **Testing**: Unit tests for data transformations
- **Better Offline Sync**: Queue changes, sync when online
- **Multi-user Collaboration**: Real-time updates between lab members
- **Image Attachments**: Photos of slices/experiments

---

*"Shipping beats perfection."*

*— Every successful software project ever*
