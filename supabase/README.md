# Supabase Backend Foundation — HandOver

This document details the Supabase backend configuration, database schema, Row Level Security (RLS) policies, storage architecture, and testing procedures for the HandOver application.

---

## 1. Database Architecture & Schema

The database is built on PostgreSQL with UUID primary keys and server-managed timestamps (`created_at`, `updated_at`).

### Entity Relationship Model

```
auth.users (Supabase Auth)
    │ (1:1 via id trigger)
    ▼
public.profiles
    │ (1:N via owner_id)
    ▼
public.handovers
    │ (1:N via handover_id)
    ▼
public.handover_events
```

---

### Tables

#### `public.profiles`
Stores user profile information corresponding directly to `auth.users(id)`. Automatically populated via the `on_auth_user_created` trigger upon user signup.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | `UUID` | `PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE` | Auth user ID |
| `full_name` | `TEXT` | | User display name |
| `email` | `TEXT` | | Contact email address |
| `phone` | `TEXT` | | Contact telephone number |
| `avatar_url` | `TEXT` | | Profile avatar URL |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT now()` | Record creation timestamp |
| `updated_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT now()` | Last update timestamp (auto-trigger) |

#### `public.handovers`
Represents an item custody transfer, tracking the lifecycle from creation through return or dispute.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | `UUID` | `PRIMARY KEY DEFAULT gen_random_uuid()` | Unique handover identifier |
| `owner_id` | `UUID` | `NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE` | Handover creator / owner |
| `recipient_name` | `TEXT` | | Name of recipient |
| `recipient_email` | `TEXT` | | Email of recipient for verification & RLS |
| `recipient_phone` | `TEXT` | | Phone number of recipient |
| `item_type` | `TEXT` | | Category/type of item |
| `item_name` | `TEXT` | `NOT NULL` | Name of the handover item |
| `description` | `TEXT` | | Optional item description |
| `photo_url` | `TEXT` | | Path to photo in private storage bucket |
| `purpose` | `TEXT` | | Handover purpose / agreement notes |
| `status` | `TEXT` | `NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','RECEIVED','RETURNED','CANCELLED','DISPUTED','EXPIRED'))` | Handover state |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT now()` | Record creation timestamp |
| `expected_return_at` | `TIMESTAMPTZ` | | Due return date/time |
| `received_at` | `TIMESTAMPTZ` | | Timestamp item was received by recipient |
| `returned_at` | `TIMESTAMPTZ` | | Timestamp item was returned to owner |
| `updated_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT now()` | Last update timestamp (auto-trigger) |

#### `public.handover_events`
Audit trail capturing every state transition or custody event for transparency and non-repudiation.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | `UUID` | `PRIMARY KEY DEFAULT gen_random_uuid()` | Unique event identifier |
| `handover_id` | `UUID` | `NOT NULL REFERENCES public.handovers(id) ON DELETE CASCADE` | Associated handover |
| `event_type` | `TEXT` | `NOT NULL` | Event identifier (e.g., `CREATED`, `RECEIVED`, `RETURNED`) |
| `performed_by` | `UUID` | `REFERENCES public.profiles(id) ON DELETE SET NULL` | User performing the action |
| `metadata` | `JSONB` | `NOT NULL DEFAULT '{}'::jsonb` | Context data (location, notes, device info) |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT now()` | Event timestamp |

---

## 2. Handover Statuses

The database strictly enforces the 6 core business statuses via `CHECK (status IN (...))`:

- `PENDING`: Handover created by owner, awaiting recipient receipt/confirmation.
- `RECEIVED`: Recipient confirmed receipt and custody of item.
- `RETURNED`: Item returned back to owner and custody closed.
- `CANCELLED`: Handover cancelled by owner prior to receipt.
- `DISPUTED`: Issue or discrepancy raised during custody or return.
- `EXPIRED`: Expected return date passed without return confirmation.

---

## 3. Database Indexes

High-performance indexing targeting primary query paths:
- `idx_handovers_owner_id`: Speeds up dashboard queries filtering by `owner_id`.
- `idx_handovers_status`: Filters active, pending, or returned handovers.
- `idx_handovers_expected_return_at`: Supports overdue / expiry queries.
- `idx_handovers_recipient_email`: Accelerates recipient access checks under RLS.
- `idx_handover_events_handover_id`: Fast audit log retrieval per handover.

---

## 4. Row Level Security (RLS) Rules

RLS is strictly enabled on `profiles`, `handovers`, `handover_events`, and `storage.objects`. Insecure wildcards like `auth.uid() IS NOT NULL` are forbidden.

### `profiles`
- **SELECT**: `auth.uid() = id` (Users can only read their own profile).
- **UPDATE**: `auth.uid() = id` (Users can only modify their own profile).
- **INSERT**: `auth.uid() = id` (Users can only create their own profile).

### `handovers`
- **INSERT**: `auth.uid() = owner_id` (Users can only create handovers they own).
- **SELECT**: Handover owner (`auth.uid() = owner_id`) OR matching recipient by email (`lower(recipient_email) = lower(auth.jwt()->>'email')`).
- **UPDATE**: Owner or verified recipient can update handover status or fields.

### `handover_events`
- **SELECT**: Accessible only if user is the owner or recipient of the parent handover.
- **INSERT**: `auth.uid() = performed_by` AND user must be an authorized participant on the parent handover.

---

## 5. Storage Bucket Configuration

- **Bucket Name**: `handover-items`
- **Access**: `public = false` (Private bucket).
- **Folder Structure**: `{owner_user_id}/{unique_filename}`
- **Storage Policies**:
  - **INSERT**: Authenticated user restricted to their own root folder (`(storage.foldername(name))[1] = auth.uid()::text`).
  - **SELECT**: Owner of the folder OR authorized recipient/owner of the associated handover referencing `photo_url`.
  - **DELETE**: Owner of the folder only.

---

## 6. Authentication Setup

Supabase Auth provides the identity provider:
- **Email/Password**: Signup, Login, Password Reset, and Session persistence.
- **Auto Profile Provisioning**: Handled automatically via PostgreSQL trigger `on_auth_user_created` which reads `NEW.raw_user_meta_data->>'full_name'` and seeds `public.profiles`.

---

## 7. Migrations

Migrations are stored in `supabase/migrations/`:
- `supabase/migrations/20261008000000_initial_schema.sql`: Contains extensions, table definitions, constraints, triggers, indexes, RLS policies, and storage bucket configuration.

### Applying Migrations

#### Option A: Supabase CLI (Linked Project)
```bash
npx supabase db push
```

#### Option B: Supabase Dashboard SQL Editor
1. Open your Supabase Dashboard -> **SQL Editor**.
2. Paste the contents of `supabase/migrations/20261008000000_initial_schema.sql`.
3. Click **Run**.

---

## 8. Backend Verification & Testing

An independent automated verification script tests all 14 backend security and functional criteria:
1. User signup (Email/Password)
2. User login & session creation
3. User logout & session termination
4. Profile creation via trigger
5. Owner read own profile
6. Unauthorized user cannot read another user's profile
7. User can create a handover
8. Owner can read their handover
9. Owner can update their handover
10. Unauthorized users cannot access another user's private handover
11. Handover events can be created correctly
12. Handover events are protected by RLS
13. Item photos upload to private `handover-items` bucket
14. Unauthorized users cannot download or read private storage objects

To run the verification test:
```bash
node supabase/test_backend.js
```
*(Requires `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` in local `.env`)*
