# Lab Slice Manager: Architecture Deep Dive

*A story of building a full-stack web app in a single HTML file*

---

## Table of Contents
1. [The Big Picture](#the-big-picture)
2. [Architecture Overview](#architecture-overview)
3. [The Technology Stack](#the-technology-stack)
4. [How the Pieces Connect](#how-the-pieces-connect)
5. [The Database Layer](#the-database-layer)
6. [Authentication: Magic Links](#authentication-magic-links)
7. [The Offline-First Philosophy](#the-offline-first-philosophy)
8. [Dynamic Schemas: The Secret Sauce](#dynamic-schemas-the-secret-sauce)
9. [Bugs We Encountered (And How We Squashed Them)](#bugs-we-encountered-and-how-we-squashed-them)
10. [Lessons Learned](#lessons-learned)
11. [Best Practices Discovered](#best-practices-discovered)
12. [What I'd Do Differently](#what-id-do-differently)

---

## The Big Picture

Imagine you're a neuroscience researcher. You have mice, you slice their brains, you run experiments on those slices, and you need to print tiny labels to track everything. You could use Excel, but then you'd have no sync between your office computer and your wet lab. You could build a complex enterprise app, but who has time for that?

This project is the sweet spot: a **Progressive Web App (PWA)** that runs entirely from a single HTML file, syncs to the cloud, works offline, and can even print labels for your tissue samples.

**The core insight**: You don't always need a complex build system, a separate backend, or a team of developers. Sometimes, a well-crafted single file can do the job.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        SINGLE HTML FILE                         │
│  ┌───────────────┬───────────────┬───────────────────────────┐  │
│  │    React      │   Tailwind    │      Application Code     │  │
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
│  │ (Magic Links) │   Database    │      (RLS Policies)       │  │
│  └───────────────┴───────────────┴───────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ Fallback
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      LOCAL STORAGE                              │
│         (Offline data, cached schemas, config)                  │
└─────────────────────────────────────────────────────────────────┘
```

### The "No Build Step" Philosophy

Most modern web apps require you to:
1. Install Node.js
2. Run `npm install` (and wait... and wait...)
3. Configure Webpack/Vite/whatever
4. Run a dev server
5. Build for production
6. Deploy the built files

**We skip all of that.**

Instead, we load React and Babel directly from CDNs, and the browser compiles our JSX on the fly. Is this slower? Yes, by maybe 100ms on page load. Does it matter for a lab management app used by a few researchers? Not at all.

**Trade-off accepted**: Slightly slower initial load for massively simpler development and deployment.

---

## The Technology Stack

### Frontend: React Without the Ceremony

```html
<script src="https://unpkg.com/react@18/umd/react.development.js"></script>
<script src="https://unpkg.com/react-dom@18/umd/react-dom.development.js"></script>
<script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>
```

These three lines give us:
- **React 18** with hooks, context, and all the modern goodies
- **ReactDOM** for rendering
- **Babel** for transforming JSX in the browser

We write normal React code:
```jsx
function MiceTab() {
  const [mice, setMice] = useState([]);
  // ... just regular React
}
```

And Babel transforms it to browser-compatible JavaScript automatically.

### Styling: Tailwind CSS

```html
<script src="https://cdn.tailwindcss.com"></script>
```

One line. No configuration files. No PurgeCSS setup. Just utility classes:

```jsx
<button className="px-4 py-2 bg-purple-600 hover:bg-purple-700 rounded-lg">
  Add Mouse
</button>
```

**Why Tailwind?** Because naming CSS classes is one of the hardest problems in computer science (only half joking). With Tailwind, you describe what you want (`px-4` = padding-x of 1rem) instead of inventing names like `.button-primary-large-rounded`.

### Backend: Supabase (Backend-as-a-Service)

Supabase is like Firebase, but built on PostgreSQL instead of NoSQL. This matters because:

1. **Real SQL**: You can write actual queries, joins, and use proper data types
2. **Row Level Security**: Security rules live in the database, not scattered across your code
3. **Open Source**: If Supabase disappears tomorrow, you can self-host

We use three Supabase features:
- **Authentication**: Magic link emails (no passwords to manage)
- **Database**: PostgreSQL tables for mice, slices, experiments
- **Realtime**: (Not currently used, but available for future multi-user sync)

### Icons: Lucide React

```jsx
function Icon({ name, ...props }) {
  const LucideIcon = lucide[name];
  return LucideIcon ? <LucideIcon {...props} /> : null;
}
```

We load the entire Lucide icon library and pick icons by name. It's not the most efficient approach (tree-shaking would be better), but it's simple and the library is small enough that it doesn't matter.

---

## How the Pieces Connect

### The Data Flow

```
User Action (click "Add Mouse")
        │
        ▼
React Component State Updates
        │
        ▼
Optimistic UI Update (shows immediately)
        │
        ▼
Async Supabase Call (saves to cloud)
        │
        ├── Success: Cloud and local in sync ✓
        │
        └── Failure: Show error, data still in local state
                     (saved to localStorage as backup)
```

This is called **optimistic UI**. We assume the save will succeed and update the UI immediately. If it fails, we tell the user but don't lose their data.

### The Context Provider Pattern

All shared state lives in a `DataProvider` component:

```jsx
function DataProvider({ children }) {
  const [mice, setMice] = useState([]);
  const [slices, setSlices] = useState([]);
  const [experiments, setExperiments] = useState([]);
  const [mouseSchema, setMouseSchema] = useState(DEFAULT_MOUSE_SCHEMA);
  // ... more state

  return (
    <DataContext.Provider value={{
      mice, setMice,
      slices, setSlices,
      // ... everything
    }}>
      {children}
    </DataContext.Provider>
  );
}
```

Any component can then access this data:

```jsx
function MiceTab() {
  const { mice, setMice, mouseSchema } = useData();
  // Now we have access to everything
}
```

**Why Context instead of Redux/Zustand/etc?** Because our state is simple. We have three main arrays and some configuration. Context handles this perfectly without adding another library.

---

## The Database Layer

### Schema Design

```
┌──────────────┐       ┌──────────────┐       ┌──────────────┐
│    MICE      │       │   SLICES     │       │ EXPERIMENTS  │
├──────────────┤       ├──────────────┤       ├──────────────┤
│ id (PK)      │──┐    │ id (PK)      │──┐    │ id (PK)      │
│ user_id (FK) │  │    │ user_id (FK) │  │    │ user_id (FK) │
│ mouseNumber  │  │    │ mouseId (FK) │──┘    │ sliceId (FK) │──┘
│ sex          │  │    │ region       │       │ title        │
│ genotype     │  │    │ thickness    │       │ experimentDt │
│ birthDate    │  │    │ cryosectDt   │       │ protocol     │
│ sacrificeDt  │  │    │ ...          │       │ ...          │
│ ageMonths    │  │    └──────────────┘       └──────────────┘
│ ...          │  │
└──────────────┘  │
                  │
        "One mouse has many slices"
        "One slice has many experiments"
```

This is a classic **one-to-many** relationship chain. A mouse can have multiple brain slices, and each slice can have multiple experiments performed on it.

### Row Level Security (RLS): The Unsung Hero

Here's the magic that makes public API keys safe:

```sql
-- Users can only see their own mice
CREATE POLICY "Users can view own mice" ON mice
    FOR SELECT USING (auth.uid() = user_id);

-- Users can only insert mice with their own user_id
CREATE POLICY "Users can insert own mice" ON mice
    FOR INSERT WITH CHECK (auth.uid() = user_id);
```

**How it works**: Every query automatically gets filtered. When you run `SELECT * FROM mice`, PostgreSQL secretly adds `WHERE user_id = [your_id]`. You literally cannot see other users' data, even if you try.

**The analogy**: Imagine a library where every book is tagged with the borrower's name, and you're physically incapable of seeing books with someone else's name. That's RLS.

---

## Authentication: Magic Links

### Why Magic Links?

Traditional auth flow:
1. User creates password
2. User forgets password
3. User clicks "Forgot Password"
4. User gets email
5. User creates new password
6. User forgets new password
7. Repeat forever

Magic link flow:
1. User enters email
2. User clicks link in email
3. User is logged in

**No passwords to remember. No passwords to leak. No password reset flow.**

### How It Works

```jsx
const { error } = await supabase.auth.signInWithOtp({
  email: email,
  options: {
    emailRedirectTo: window.location.origin + window.location.pathname
  }
});
```

Supabase sends an email with a special link. When clicked:
1. The link contains a secure token
2. Supabase verifies the token
3. A session is created
4. The user is redirected back to our app

### The Redirect URL Gotcha

When deploying to GitHub Pages, we hit an issue: the magic link was redirecting to `https://username.github.io/` instead of `https://username.github.io/repo-name/`.

**The fix**: Explicitly set `emailRedirectTo` to include the full path:

```jsx
emailRedirectTo: window.location.origin + window.location.pathname
```

This ensures users land back on the correct page after authentication.

---

## The Offline-First Philosophy

### The Problem

Lab computers often have:
- Spotty internet connections
- Institutional firewalls that block random services
- No IT support when things break at 2 AM

### The Solution

Everything saves to **both** the cloud and localStorage:

```jsx
// After successful cloud save
setMice([newMouse, ...mice]);

// This triggers the localStorage sync
useEffect(() => {
  if (dataLoaded) {
    localStorage.setItem('labManager_mice', JSON.stringify(mice));
  }
}, [mice]);
```

If the cloud save fails, the data is still in localStorage. Users can export/import JSON backups to transfer data between computers.

### Offline Mode

Users can click "Continue Offline" to use the app without any cloud connection:

```jsx
const offlineUser = { offline: true };
setUser(offlineUser);
```

The app works exactly the same, just without sync. When they get back online, they can use the backup/restore feature.

---

## Dynamic Schemas: The Secret Sauce

### The Problem

Different labs have different needs. One might track "Injection Site". Another might need "Antibody Used". Hardcoding fields means constant code changes.

### The Solution

Fields are defined in a schema array:

```jsx
const DEFAULT_MOUSE_SCHEMA = [
  { key: 'mouseNumber', label: 'Mouse Number', type: 'text', required: true },
  { key: 'sex', label: 'Sex', type: 'select', options: ['M', 'F'], required: false },
  { key: 'genotype', label: 'Genotype', type: 'text', required: false },
  // ...
];
```

The `DynamicForm` component reads this schema and renders the appropriate inputs:

```jsx
function DynamicForm({ schema, onSubmit }) {
  return schema.map(field => {
    if (field.type === 'text') return <input type="text" ... />;
    if (field.type === 'select') return <select ... />;
    if (field.type === 'date') return <input type="date" ... />;
    // etc.
  });
}
```

**The power**: Users can add, remove, and reorder fields through the Settings panel without touching any code.

### Schema Migration

When we add new default fields, existing users have old schemas cached. The `mergeSchemas` function handles this:

```jsx
const mergeSchemas = (defaultSchema, savedSchema) => {
  const defaultByKey = Object.fromEntries(defaultSchema.map(f => [f.key, f]));
  const savedKeys = new Set(savedSchema.map(f => f.key));
  const newFields = defaultSchema.filter(f => !savedKeys.has(f.key));
  
  // Update existing fields with default's required property
  const updatedSaved = savedSchema.map(f => {
    if (defaultByKey[f.key]) {
      return { ...f, required: defaultByKey[f.key].required };
    }
    return f;
  });
  
  return [...newFields, ...updatedSaved];
};
```

This ensures:
1. New fields get added automatically
2. Changed properties (like `required`) get updated
3. User customizations (field order, custom fields) are preserved

---

## Bugs We Encountered (And How We Squashed Them)

### Bug #1: "Invalid input syntax for type integer"

**Symptom**: Saving a form with empty number fields crashed.

**Root cause**: Empty form fields return `""` (empty string). PostgreSQL expected `NULL` or a number, not an empty string.

**The fix**:
```jsx
const handleSubmit = (e) => {
  const cleanedData = {};
  Object.keys(form).forEach(key => {
    const field = schema.find(f => f.key === key);
    if (field?.type === 'number') {
      cleanedData[key] = form[key] === '' ? null : Number(form[key]);
    } else {
      cleanedData[key] = form[key] === '' ? null : form[key];
    }
  });
  onSubmit(cleanedData);
};
```

**Lesson**: Always sanitize data at the boundary between your app and external systems.

### Bug #2: RLS Policy Violation

**Symptom**: "New row violates row-level security policy for table experiments"

**Root cause**: We were inserting records without the `user_id` field, but RLS required it.

**The fix**:
```jsx
// Before (broken)
await supabase.from('experiments').insert(newExp);

// After (working)
await supabase.from('experiments').insert({ ...newExp, user_id: user.id });
```

**Lesson**: RLS is strict by design. If your policy says `user_id = auth.uid()`, you must provide `user_id` on insert.

### Bug #3: Manual Age Not Displaying

**Symptom**: User entered age manually, but table showed "N/A".

**Root cause**: Display logic checked `age.days !== null`, but manual ages only have `months`, not `days`.

**The fix**:
```jsx
// Before (broken)
{age.days !== null ? `${age.months}m` : 'N/A'}

// After (working)
{age.months !== null ? `${age.months}m` : 'N/A'}
```

**Lesson**: When you have multiple code paths that produce similar data structures, ensure your display logic handles all variations.

### Bug #4: Abbreviations in Template Literals

**Symptom**: Labels printed "undefined" instead of "M" or "F".

**Root cause**: Functions like `abbrevSex()` couldn't be called inside template literal strings being passed to `document.write()`.

**The fix**: Pre-compute values before the template:
```jsx
// Before (broken)
`<div>${abbrevSex(mouse.sex)}</div>`

// After (working)
const sexAbbrev = abbrevSex(mouse?.sex);
// ... later in template
`<div>${sexAbbrev}</div>`
```

**Lesson**: Template literals in strings passed to other contexts (like `document.write()`) don't have access to your local functions.

### Bug #5: Sex Field Still Required

**Symptom**: Changed `required: true` to `required: false`, but form still demanded a value.

**Root cause**: Old schema with `required: true` was cached in localStorage.

**The fix**: Updated `mergeSchemas` to sync the `required` property:
```jsx
const updatedSaved = savedSchema.map(f => {
  if (defaultByKey[f.key]) {
    return { ...f, required: defaultByKey[f.key].required };
  }
  return f;
});
```

**Lesson**: When you have cached configuration, you need migration logic. Schema evolution is a real problem even in simple apps.

### Bug #6: Network Errors on Institutional Networks

**Symptom**: Magic links worked in the office but failed in the wet lab.

**Root cause**: Institutional firewalls often block unfamiliar domains like `*.supabase.co`.

**The fix**: No code fix possible. Solutions:
1. Ask IT to whitelist the domain
2. Use a VPN
3. Use mobile hotspot
4. Work in offline mode

**Lesson**: Enterprise/institutional networks are hostile environments. Always have an offline fallback.

---

## Lessons Learned

### 1. Start Simple, Add Complexity Only When Needed

We started with a single HTML file. No build system, no bundler, no package.json. This let us iterate incredibly fast in the early stages.

**The temptation**: "But what about code splitting? Tree shaking? Hot module replacement?"

**The reality**: For a lab tool used by a handful of researchers, none of that matters. Ship something useful first.

### 2. Optimistic UI with Graceful Degradation

Update the UI immediately, save to the cloud in the background, and handle failures gracefully:

```jsx
// Update local state immediately
setMice([newMouse, ...mice]);

// Save to cloud (might fail)
try {
  await supabase.from('mice').insert(newMouse);
} catch (err) {
  alert('Error saving to cloud. Data saved locally.');
}
```

Users see instant feedback. If the cloud fails, they don't lose work.

### 3. Error Messages Are User Interface

Our early code swallowed errors silently. Users would save data, and it would mysteriously disappear on refresh (because the cloud save failed silently).

**Now**: Every database operation has explicit error handling and user-facing messages:

```jsx
if (error) {
  console.error('Supabase error:', error);
  alert('Error saving to cloud: ' + error.message + '\n\nData saved locally.');
}
```

### 4. Security Through Architecture, Not Obscurity

We were initially worried about exposing Supabase API keys in public code. But the architecture makes this safe:

- The `anon` key is **designed** to be public
- RLS policies enforce data isolation at the database level
- Users can only access their own data, period

This is better than hiding keys in environment variables and hoping nobody finds them.

### 5. Schema Evolution Is Hard

Even in a simple app, schemas change:
- New fields get added
- Required fields become optional
- Options lists change

The `mergeSchemas` function handles this, but it's still tricky. Every schema change needs to consider:
- What happens to existing data?
- What happens to cached schemas?
- What database migrations are needed?

### 6. Dates and Times Are Always Complicated

We have:
- Birth dates (just a date, no time)
- Sacrifice dates (just a date)
- Cryosection dates (just a date)
- Created timestamps (full datetime with timezone)

Each requires slightly different handling. And then there's age calculation, which has edge cases around month lengths.

**Advice**: Use a date library for anything non-trivial. We did manual math and it mostly works, but it's fragile.

---

## Best Practices Discovered

### 1. Defensive Programming

Always check if data exists before using it:

```jsx
// Bad
const age = calculateAge(mouse.birthDate);

// Good
const age = mouse ? calculateAge(mouse.birthDate, mouse.sacrificeDate) : null;
```

### 2. Consistent Data Transformation

We created helper functions for common transformations:

```jsx
function abbrevSex(sex) {
  if (!sex) return '?';
  if (sex === 'Male' || sex === 'M') return 'M';
  if (sex === 'Female' || sex === 'F') return 'F';
  return sex;
}
```

This handles:
- Null/undefined values
- Legacy data ("Male" vs "M")
- Unknown values (returns as-is)

### 3. Single Source of Truth

Schemas are defined once as constants:

```jsx
const DEFAULT_MOUSE_SCHEMA = [...];
const DEFAULT_SLICE_SCHEMA = [...];
const DEFAULT_EXPERIMENT_SCHEMA = [...];
```

Everything else references these. No duplicating field lists across components.

### 4. Fail Loud, Recover Gracefully

```jsx
try {
  const { error } = await supabase.from('mice').update(data).eq('id', id);
  if (error) {
    console.error('Supabase error:', error);  // Fail loud (for debugging)
    alert('Error: ' + error.message);          // Inform user
  }
} catch (err) {
  console.error('Exception:', err);            // Fail loud
  alert('Unexpected error');                   // Inform user
}
// Data is saved locally regardless                // Recover gracefully
setMice(mice.map(m => m.id === id ? {...m, ...data} : m));
```

### 5. IDs Should Be Readable

We generate IDs like `M-LXK8F3-A2B4` instead of UUIDs like `550e8400-e29b-41d4-a716-446655440000`.

Researchers need to read these IDs, write them on tubes, and discuss them with colleagues. Human-friendly IDs matter.

---

## What I'd Do Differently

### 1. TypeScript from the Start

As the codebase grew, keeping track of data shapes became harder. TypeScript would catch bugs like:

```typescript
// TypeScript would catch this
mouse.birthdate  // Error: did you mean 'birthDate'?
```

### 2. Proper State Management

React Context works, but as the app grew, we ended up with a lot of state in one place. Something like Zustand would provide:
- Better organization
- Easier debugging
- Computed/derived state

### 3. Component Library

We reinvented several UI patterns (modals, sortable tables, form inputs). A component library like shadcn/ui would have saved time and provided better accessibility.

### 4. Testing

We have no automated tests. For a small project, this was fine. But bugs like "wrong property checked for age display" would be caught instantly by a simple unit test:

```javascript
test('getMouseAge returns manual age when no birthDate', () => {
  const mouse = { ageMonths: 6 };
  const age = getMouseAge(mouse);
  expect(age.months).toBe(6);
});
```

### 5. Better Offline Sync

Currently, offline mode is "all or nothing". A proper sync system would:
- Queue changes made offline
- Sync when connection returns
- Handle conflicts between offline and online changes

This is complex, but libraries like PouchDB or Watermelon DB make it manageable.

---

## Conclusion

This project proves that modern web development doesn't require a complex setup. A single HTML file can:
- Use React with hooks
- Connect to a cloud database
- Handle authentication
- Work offline
- Print physical labels

The key insights:
1. **Simplicity is a feature**. Fewer moving parts means fewer things to break.
2. **Progressive enhancement works**. Start with local storage, add cloud sync, keep offline as fallback.
3. **Security can be architectural**. RLS makes public API keys safe.
4. **User feedback matters**. Always tell users what's happening, especially when things fail.

The app isn't perfect. The code could be cleaner, the architecture more scalable. But it solves a real problem for real researchers, and it shipped. That's what matters.

---

*"Shipping beats perfection."*

*— Every successful software project ever*
