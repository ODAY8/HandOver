-- ==============================================================================
-- Handover Supabase Initial Schema Migration
-- Migration: 20261008000000_initial_schema.sql
-- ==============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==============================================================================
-- 2. TABLES
-- ==============================================================================

-- 2.1 PROFILES TABLE
-- Profile id corresponds directly to authenticated Supabase user in auth.users
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT,
    email TEXT,
    phone TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2.2 HANDOVERS TABLE
-- Core handover record representing physical custody transition
CREATE TABLE IF NOT EXISTS public.handovers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    recipient_name TEXT,
    recipient_email TEXT,
    recipient_phone TEXT,
    item_type TEXT,
    item_name TEXT NOT NULL,
    description TEXT,
    photo_url TEXT,
    purpose TEXT,
    status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'RECEIVED', 'RETURNED', 'CANCELLED', 'DISPUTED', 'EXPIRED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expected_return_at TIMESTAMPTZ,
    received_at TIMESTAMPTZ,
    returned_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2.3 HANDOVER_EVENTS TABLE
-- Audit trail and custody history for each handover
CREATE TABLE IF NOT EXISTS public.handover_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    handover_id UUID NOT NULL REFERENCES public.handovers(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    performed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ==============================================================================
-- 3. INDEXES
-- ==============================================================================
CREATE INDEX IF NOT EXISTS idx_handovers_owner_id ON public.handovers(owner_id);
CREATE INDEX IF NOT EXISTS idx_handovers_status ON public.handovers(status);
CREATE INDEX IF NOT EXISTS idx_handovers_expected_return_at ON public.handovers(expected_return_at);
CREATE INDEX IF NOT EXISTS idx_handovers_recipient_email ON public.handovers(recipient_email);
CREATE INDEX IF NOT EXISTS idx_handover_events_handover_id ON public.handover_events(handover_id);

-- ==============================================================================
-- 4. TRIGGERS & AUTOMATION
-- ==============================================================================

-- 4.1 Update updated_at timestamp function
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_profiles_updated_at ON public.profiles;
CREATE TRIGGER trg_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS trg_handovers_updated_at ON public.handovers;
CREATE TRIGGER trg_handovers_updated_at
    BEFORE UPDATE ON public.handovers
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- 4.2 Auto-create profile on auth.users signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, email, phone, avatar_url)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
        NEW.email,
        NEW.phone,
        COALESCE(NEW.raw_user_meta_data->>'avatar_url', '')
    )
    ON CONFLICT (id) DO UPDATE
    SET
        email = EXCLUDED.email,
        full_name = CASE WHEN profiles.full_name IS NULL OR profiles.full_name = '' THEN EXCLUDED.full_name ELSE profiles.full_name END;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ==============================================================================
-- 5. ROW LEVEL SECURITY (RLS)
-- ==============================================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.handovers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.handover_events ENABLE ROW LEVEL SECURITY;

-- 5.1 PROFILES POLICIES
-- Users can read their own profile
DROP POLICY IF EXISTS "Users can read own profile" ON public.profiles;
CREATE POLICY "Users can read own profile"
    ON public.profiles
    FOR SELECT
    USING (auth.uid() = id);

-- Users can update their own profile
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
    ON public.profiles
    FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- Users can insert their own profile
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Users can insert own profile"
    ON public.profiles
    FOR INSERT
    WITH CHECK (auth.uid() = id);

-- 5.2 HANDOVERS POLICIES
-- Owners can create handovers for themselves
DROP POLICY IF EXISTS "Owners can create handovers" ON public.handovers;
CREATE POLICY "Owners can create handovers"
    ON public.handovers
    FOR INSERT
    WITH CHECK (auth.uid() = owner_id);

-- Authorized users (owner or recipient by email) can view handovers
DROP POLICY IF EXISTS "Authorized users can view handovers" ON public.handovers;
CREATE POLICY "Authorized users can view handovers"
    ON public.handovers
    FOR SELECT
    USING (
        auth.uid() = owner_id
        OR (
            recipient_email IS NOT NULL
            AND lower(recipient_email) = lower(COALESCE(auth.jwt()->>'email', ''))
        )
    );

-- Authorized users can update their handovers (e.g. status transition, return, resolution)
DROP POLICY IF EXISTS "Authorized users can update handovers" ON public.handovers;
CREATE POLICY "Authorized users can update handovers"
    ON public.handovers
    FOR UPDATE
    USING (
        auth.uid() = owner_id
        OR (
            recipient_email IS NOT NULL
            AND lower(recipient_email) = lower(COALESCE(auth.jwt()->>'email', ''))
        )
    )
    WITH CHECK (
        auth.uid() = owner_id
        OR (
            recipient_email IS NOT NULL
            AND lower(recipient_email) = lower(COALESCE(auth.jwt()->>'email', ''))
        )
    );

-- 5.3 HANDOVER_EVENTS POLICIES
-- Authorized users can view events for handovers they have access to
DROP POLICY IF EXISTS "Authorized users can view handover events" ON public.handover_events;
CREATE POLICY "Authorized users can view handover events"
    ON public.handover_events
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.handovers h
            WHERE h.id = handover_events.handover_id
              AND (
                  h.owner_id = auth.uid()
                  OR (
                      h.recipient_email IS NOT NULL
                      AND lower(h.recipient_email) = lower(COALESCE(auth.jwt()->>'email', ''))
                  )
              )
        )
    );

-- Authorized users can create events for handovers they participate in
DROP POLICY IF EXISTS "Authorized users can create handover events" ON public.handover_events;
CREATE POLICY "Authorized users can create handover events"
    ON public.handover_events
    FOR INSERT
    WITH CHECK (
        auth.uid() = performed_by
        AND EXISTS (
            SELECT 1 FROM public.handovers h
            WHERE h.id = handover_events.handover_id
              AND (
                  h.owner_id = auth.uid()
                  OR (
                      h.recipient_email IS NOT NULL
                      AND lower(h.recipient_email) = lower(COALESCE(auth.jwt()->>'email', ''))
                  )
              )
        )
    );

-- ==============================================================================
-- 6. STORAGE BUCKET & POLICIES
-- ==============================================================================

-- Create private bucket 'handover-items'
INSERT INTO storage.buckets (id, name, public)
VALUES ('handover-items', 'handover-items', false)
ON CONFLICT (id) DO UPDATE SET public = false;

-- Storage RLS: Users can upload items under their owner user ID folder
DROP POLICY IF EXISTS "Authenticated users can upload handover photos" ON storage.objects;
CREATE POLICY "Authenticated users can upload handover photos"
    ON storage.objects
    FOR INSERT
    WITH CHECK (
        bucket_id = 'handover-items'
        AND auth.uid() IS NOT NULL
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- Storage RLS: Users can view photos in their own folder or if authorized
DROP POLICY IF EXISTS "Authorized users can read handover photos" ON storage.objects;
CREATE POLICY "Authorized users can read handover photos"
    ON storage.objects
    FOR SELECT
    USING (
        bucket_id = 'handover-items'
        AND auth.uid() IS NOT NULL
        AND (
            (storage.foldername(name))[1] = auth.uid()::text
            OR EXISTS (
                SELECT 1 FROM public.handovers h
                WHERE h.photo_url LIKE '%' || name || '%'
                  AND (
                      h.owner_id = auth.uid()
                      OR (
                          h.recipient_email IS NOT NULL
                          AND lower(h.recipient_email) = lower(COALESCE(auth.jwt()->>'email', ''))
                      )
                  )
            )
        )
    );

-- Storage RLS: Owners can delete photos in their own folder
DROP POLICY IF EXISTS "Owners can delete own handover photos" ON storage.objects;
CREATE POLICY "Owners can delete own handover photos"
    ON storage.objects
    FOR DELETE
    USING (
        bucket_id = 'handover-items'
        AND auth.uid() IS NOT NULL
        AND (storage.foldername(name))[1] = auth.uid()::text
    );
