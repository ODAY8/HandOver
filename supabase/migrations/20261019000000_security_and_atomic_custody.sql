-- ==============================================================================
-- HandOver Phase 2 Migration: Security Hardening & Atomic Custody
-- Migration: 20261019000000_security_and_atomic_custody.sql
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. FIRST-CLASS DEDICATED TOKEN COLUMN & SAFE DATA BACKFILL
-- ------------------------------------------------------------------------------

-- 1.1 Add dedicated token column
ALTER TABLE public.handovers
ADD COLUMN IF NOT EXISTS token TEXT;

-- 1.2 Safe backfill from purpose JSON (defensive against plain-text notes)
DO $$
DECLARE
    r RECORD;
    v_meta JSONB;
    v_tok TEXT;
BEGIN
    FOR r IN
        SELECT id, purpose, created_at
        FROM public.handovers
        WHERE token IS NULL AND purpose IS NOT NULL
    LOOP
        BEGIN
            -- Only attempt jsonb cast if purpose starts with an object brace
            IF r.purpose ~ '^\s*\{' THEN
                v_meta := r.purpose::jsonb;
                v_tok := v_meta->>'token';
                IF v_tok IS NOT NULL AND trim(v_tok) <> '' THEN
                    UPDATE public.handovers
                    SET token = trim(v_tok)
                    WHERE id = r.id;
                END IF;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            -- Plain text or invalid JSON is safely ignored
            NULL;
        END;
    END LOOP;
END $$;

-- 1.3 Deduplicate legacy tokens before unique constraint enforcement
-- Resolution Strategy:
-- The earliest record (by created_at ASC, id ASC) retains its original token (e.g. HN-1048),
-- preserving the validity of physical QR codes previously printed or shared for that item.
-- Subsequent duplicate records are deterministically disambiguated with '-DUP' + counter,
-- verifying uniqueness against all existing records in a collision-checked loop.
-- Legacy purpose JSON is updated in lockstep if it was formatted as JSON.
DO $$
DECLARE
    r RECORD;
    v_cand_tok TEXT;
    v_counter INT;
    v_meta JSONB;
BEGIN
    FOR r IN
        SELECT id, token, purpose,
               ROW_NUMBER() OVER (PARTITION BY lower(trim(token)) ORDER BY created_at ASC, id ASC) AS row_num
        FROM public.handovers
        WHERE token IS NOT NULL AND trim(token) <> ''
    LOOP
        IF r.row_num > 1 THEN
            v_counter := 1;
            LOOP
                v_cand_tok := r.token || '-DUP' || v_counter::text;
                EXIT WHEN NOT EXISTS (
                    SELECT 1 FROM public.handovers WHERE lower(trim(token)) = lower(v_cand_tok)
                );
                v_counter := v_counter + 1;
            END LOOP;

            UPDATE public.handovers SET token = v_cand_tok WHERE id = r.id;

            BEGIN
                IF r.purpose IS NOT NULL AND r.purpose ~ '^\s*\{' THEN
                    v_meta := r.purpose::jsonb;
                    v_meta := jsonb_set(v_meta, '{token}', to_jsonb(v_cand_tok));
                    UPDATE public.handovers SET purpose = v_meta::text WHERE id = r.id;
                END IF;
            EXCEPTION WHEN OTHERS THEN
                NULL;
            END;
        END IF;
    END LOOP;
END $$;

-- 1.4 Backfill any remaining handovers with collision-proof high-entropy tokens
-- For each record where token IS NULL or empty:
-- Generates a candidate token derived from the row UUID (HN-<8-HEX>),
-- checks against existing tokens, and appends a numeric counter if a collision occurs.
DO $$
DECLARE
    r RECORD;
    v_cand_tok TEXT;
    v_counter INT;
    v_meta JSONB;
BEGIN
    FOR r IN
        SELECT id, purpose, created_at
        FROM public.handovers
        WHERE token IS NULL OR trim(token) = ''
        ORDER BY created_at ASC, id ASC
    LOOP
        v_counter := 1;
        LOOP
            v_cand_tok := 'HN-' || upper(substr(replace(r.id::text, '-', ''), 1, 8)) ||
                          CASE WHEN v_counter > 1 THEN '-' || v_counter::text ELSE '' END;
            EXIT WHEN NOT EXISTS (
                SELECT 1 FROM public.handovers WHERE lower(trim(token)) = lower(v_cand_tok)
            );
            v_counter := v_counter + 1;
        END LOOP;

        UPDATE public.handovers SET token = v_cand_tok WHERE id = r.id;

        BEGIN
            IF r.purpose IS NOT NULL AND r.purpose ~ '^\s*\{' THEN
                v_meta := r.purpose::jsonb;
                v_meta := jsonb_set(v_meta, '{token}', to_jsonb(v_cand_tok));
                UPDATE public.handovers SET purpose = v_meta::text WHERE id = r.id;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
    END LOOP;
END $$;

-- 1.5 Enforce token column constraints
ALTER TABLE public.handovers
ALTER COLUMN token SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_handovers_token_unique
ON public.handovers (lower(trim(token)));

-- ------------------------------------------------------------------------------
-- 2. BLOCK DIRECT UPDATES & ENFORCE RPC-ONLY CUSTODY TRANSITIONS
-- ------------------------------------------------------------------------------

-- 2.1 Replace overly broad UPDATE policy on handovers
DROP POLICY IF EXISTS "Authorized users can update handovers" ON public.handovers;
DROP POLICY IF EXISTS "Owners can update own handover non-custody metadata" ON public.handovers;

-- Direct updates are restricted exclusively to the handover owner
CREATE POLICY "Owners can update own handover non-custody metadata"
ON public.handovers
FOR UPDATE
USING (auth.uid() = owner_id)
WITH CHECK (auth.uid() = owner_id);

-- 2.2 Immutability and direct mutation prevention trigger
CREATE OR REPLACE FUNCTION public.trg_protect_handover_immutability()
RETURNS TRIGGER AS $$
DECLARE
    v_transition_active TEXT;
BEGIN
    v_transition_active := current_setting('handover.transition_in_progress', true);

    -- 1. Ownership (owner_id) is permanently immutable
    IF OLD.owner_id IS DISTINCT FROM NEW.owner_id THEN
        RAISE EXCEPTION 'Ownership of a handover cannot be altered (owner_id is immutable)'
            USING ERRCODE = '42501';
    END IF;

    -- 2. Creation timestamp (created_at) is permanently immutable
    IF OLD.created_at IS DISTINCT FROM NEW.created_at THEN
        RAISE EXCEPTION 'Creation timestamp (created_at) is immutable'
            USING ERRCODE = '42501';
    END IF;

    -- 3. Token is immutable once custody has begun or for non-owners
    IF OLD.token IS DISTINCT FROM NEW.token AND OLD.token IS NOT NULL THEN
        IF OLD.status <> 'PENDING' OR auth.uid() IS DISTINCT FROM OLD.owner_id THEN
            RAISE EXCEPTION 'Reference token cannot be modified once custody has begun or by non-owners'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    -- 4. Status and custody timestamps CANNOT be changed directly via PostgREST
    -- They must ONLY be modified from inside an authorized atomic RPC
    IF (OLD.status IS DISTINCT FROM NEW.status OR
        OLD.received_at IS DISTINCT FROM NEW.received_at OR
        OLD.returned_at IS DISTINCT FROM NEW.returned_at) AND
       (v_transition_active IS DISTINCT FROM 'true') THEN
        RAISE EXCEPTION 'Direct updates to status or custody timestamps are prohibited. Custody transitions must use transition RPCs.'
            USING ERRCODE = '42501';
    END IF;

    -- 5. Non-owners cannot modify item or recipient specifications
    IF auth.uid() IS DISTINCT FROM OLD.owner_id AND (v_transition_active IS DISTINCT FROM 'true') THEN
        IF OLD.item_name IS DISTINCT FROM NEW.item_name OR
           OLD.item_type IS DISTINCT FROM NEW.item_type OR
           OLD.description IS DISTINCT FROM NEW.description OR
           OLD.photo_url IS DISTINCT FROM NEW.photo_url OR
           OLD.recipient_email IS DISTINCT FROM NEW.recipient_email OR
           OLD.expected_return_at IS DISTINCT FROM NEW.expected_return_at THEN
            RAISE EXCEPTION 'Only the handover owner can modify item and recipient specifications'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    -- 6. Item details cannot be modified once custody is no longer PENDING
    IF OLD.status <> 'PENDING' AND (v_transition_active IS DISTINCT FROM 'true') THEN
        IF OLD.item_name IS DISTINCT FROM NEW.item_name OR
           OLD.item_type IS DISTINCT FROM NEW.item_type OR
           OLD.photo_url IS DISTINCT FROM NEW.photo_url OR
           OLD.recipient_email IS DISTINCT FROM NEW.recipient_email OR
           OLD.expected_return_at IS DISTINCT FROM NEW.expected_return_at THEN
            RAISE EXCEPTION 'Handover details cannot be modified once custody transition has begun'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

DROP TRIGGER IF EXISTS trg_protect_handover_immutability ON public.handovers;
CREATE TRIGGER trg_protect_handover_immutability
BEFORE UPDATE ON public.handovers
FOR EACH ROW EXECUTE FUNCTION public.trg_protect_handover_immutability();

-- 2.3 Direct event creation trigger: anti-flooding and concurrency lock
CREATE OR REPLACE FUNCTION public.trg_enforce_handover_event_limits()
RETURNS TRIGGER AS $$
DECLARE
    v_count INT;
BEGIN
    -- Only enforce concurrency lock and event count limit on CREATED / initial creation & renewal events
    IF NEW.event_type = 'CREATED' THEN
        -- Concurrency control: Lock the parent handover row FOR UPDATE
        -- This serializes concurrent event creations for the same handover
        PERFORM 1 FROM public.handovers
        WHERE id = NEW.handover_id
        FOR UPDATE;

        SELECT count(*) INTO v_count
        FROM public.handover_events
        WHERE handover_id = NEW.handover_id
          AND event_type = 'CREATED';

        IF v_count >= 3 THEN
            RAISE EXCEPTION 'Event limit exceeded: Handover cannot have more than 3 creation or renewal events'
                USING ERRCODE = 'P0001';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

DROP TRIGGER IF EXISTS trg_enforce_handover_event_limits ON public.handover_events;
CREATE TRIGGER trg_enforce_handover_event_limits
BEFORE INSERT ON public.handover_events
FOR EACH ROW EXECUTE FUNCTION public.trg_enforce_handover_event_limits();

-- Restrict direct event creation to initial CREATED event only
-- (No self-referential subquery on public.handover_events to prevent RLS recursion)
DROP POLICY IF EXISTS "Authorized users can create handover events" ON public.handover_events;
DROP POLICY IF EXISTS "Owners can create initial creation event" ON public.handover_events;
CREATE POLICY "Owners can create initial creation event"
ON public.handover_events
FOR INSERT
WITH CHECK (
    auth.uid() = performed_by
    AND event_type = 'CREATED'
    AND EXISTS (
        SELECT 1 FROM public.handovers h
        WHERE h.id = handover_events.handover_id
          AND h.owner_id = auth.uid()
          AND h.status = 'PENDING'
    )
);

-- ------------------------------------------------------------------------------
-- 3. STORAGE RLS HARDENING: EXACT MATCHING & STRICT FOLDER OWNERSHIP
-- ------------------------------------------------------------------------------

-- Drop known baseline and Phase 2 storage policies on handover-items
DROP POLICY IF EXISTS "Authorized users can read handover photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload handover photos" ON storage.objects;
DROP POLICY IF EXISTS "Owners can delete own handover photos" ON storage.objects;
DROP POLICY IF EXISTS "Owners can update own handover photos" ON storage.objects;

-- Defensively drop any legacy/conflicting policies referencing handover-items
-- to prevent permissive OR logic bypasses, without touching unrelated buckets
DO $$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN
        SELECT policyname
        FROM pg_policies
        WHERE schemaname = 'storage'
          AND tablename = 'objects'
          AND (
              qual ILIKE '%handover-items%'
              OR with_check ILIKE '%handover-items%'
              OR policyname IN (
                  'Authenticated users can upload handover photos',
                  'Owners can update own handover photos',
                  'Owners can delete own handover photos',
                  'Authorized users can read handover photos'
              )
          )
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects', pol.policyname);
    END LOOP;
END $$;

-- 3.1 INSERT: User can upload ONLY into their own folder: {auth.uid()}/...
CREATE POLICY "Authenticated users can upload handover photos"
ON storage.objects
FOR INSERT
WITH CHECK (
    bucket_id = 'handover-items'
    AND auth.uid() IS NOT NULL
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- 3.2 UPDATE: User can update ONLY files in their own folder
CREATE POLICY "Owners can update own handover photos"
ON storage.objects
FOR UPDATE
USING (
    bucket_id = 'handover-items'
    AND auth.uid() IS NOT NULL
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- 3.3 DELETE: User can delete ONLY files in their own folder
CREATE POLICY "Owners can delete own handover photos"
ON storage.objects
FOR DELETE
USING (
    bucket_id = 'handover-items'
    AND auth.uid() IS NOT NULL
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- 3.4 SELECT: User can read if folder owner OR legitimate recipient on associated handover
CREATE POLICY "Authorized users can read handover photos"
ON storage.objects
FOR SELECT
USING (
    bucket_id = 'handover-items'
    AND auth.uid() IS NOT NULL
    AND (
        -- Option A: Authenticated user reading from their own folder
        (storage.foldername(name))[1] = auth.uid()::text
        OR
        -- Option B: Verified recipient or owner on an active handover referencing this exact object
        -- Critical anchor: (storage.foldername(name))[1] MUST match handover owner_id to prevent IDOR path injection
        EXISTS (
            SELECT 1 FROM public.handovers h
            WHERE (
                name = h.photo_url
                OR name = (h.owner_id::text || '/' || h.photo_url)
            )
            AND (storage.foldername(name))[1] = h.owner_id::text
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

-- ------------------------------------------------------------------------------
-- 4. ATOMIC CUSTODY TRANSITION RPCS (LEAST PRIVILEGE & STRICT ROLES)
-- ------------------------------------------------------------------------------

-- 4.1 Confirm Receipt (STRICTLY Recipient only; PENDING -> RECEIVED)
CREATE OR REPLACE FUNCTION public.confirm_handover_receipt(
    p_handover_id UUID
)
RETURNS jsonb AS $$
DECLARE
    v_handover public.handovers%ROWTYPE;
    v_caller_id UUID;
    v_caller_email TEXT;
    v_performer_name TEXT;
BEGIN
    v_caller_id := auth.uid();
    v_caller_email := lower(COALESCE(auth.jwt()->>'email', ''));

    IF v_caller_id IS NULL OR v_caller_email = '' THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    -- Concurrency control: Lock the row FOR UPDATE
    SELECT * INTO v_handover
    FROM public.handovers
    WHERE id = p_handover_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Handover record not found' USING ERRCODE = 'P0002';
    END IF;

    -- Strict recipient role enforcement: Caller MUST be the intended recipient
    IF v_handover.recipient_email IS NULL OR lower(v_handover.recipient_email) <> v_caller_email THEN
        RAISE EXCEPTION 'Access denied: caller (%) is not the authorized recipient (%) of this handover',
            v_caller_email, COALESCE(v_handover.recipient_email, 'none')
            USING ERRCODE = '42501';
    END IF;

    -- Idempotency check: if already RECEIVED, return current state without duplicate event
    IF v_handover.status = 'RECEIVED' THEN
        RETURN to_jsonb(v_handover);
    END IF;

    -- State machine validation: Only PENDING items can be received
    IF v_handover.status <> 'PENDING' THEN
        RAISE EXCEPTION 'Cannot confirm receipt: invalid transition from status % (must be PENDING)', v_handover.status
            USING ERRCODE = '23514';
    END IF;

    -- Derive trusted display name from profiles or fallback
    SELECT COALESCE(NULLIF(trim(full_name), ''), 'Recipient')
    INTO v_performer_name
    FROM public.profiles
    WHERE id = v_caller_id;

    IF v_performer_name IS NULL THEN
        v_performer_name := 'Recipient';
    END IF;

    -- Authorize internal status update in trigger
    PERFORM set_config('handover.transition_in_progress', 'true', true);

    -- 1. Atomic status update
    UPDATE public.handovers
    SET status = 'RECEIVED',
        received_at = COALESCE(v_handover.received_at, now()),
        updated_at = now()
    WHERE id = p_handover_id
    RETURNING * INTO v_handover;

    -- 2. Atomic event insert
    INSERT INTO public.handover_events (
        handover_id,
        event_type,
        performed_by,
        metadata,
        created_at
    ) VALUES (
        p_handover_id,
        'RECEIVED',
        v_caller_id,
        jsonb_build_object(
            'title', v_performer_name || ' confirmed physical receipt',
            'performer_name', v_performer_name
        ),
        now()
    );

    PERFORM set_config('handover.transition_in_progress', 'false', true);

    RETURN to_jsonb(v_handover);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

-- 4.2 Confirm Return (STRICTLY Owner only; RECEIVED/DISPUTED -> RETURNED)
CREATE OR REPLACE FUNCTION public.confirm_handover_return(
    p_handover_id UUID
)
RETURNS jsonb AS $$
DECLARE
    v_handover public.handovers%ROWTYPE;
    v_caller_id UUID;
    v_performer_name TEXT;
BEGIN
    v_caller_id := auth.uid();

    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    -- Concurrency control: Lock the row FOR UPDATE
    SELECT * INTO v_handover
    FROM public.handovers
    WHERE id = p_handover_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Handover record not found' USING ERRCODE = 'P0002';
    END IF;

    -- Strict role enforcement: Only the owner can confirm return
    IF v_handover.owner_id <> v_caller_id THEN
        RAISE EXCEPTION 'Access denied: only the handover owner can confirm physical return'
            USING ERRCODE = '42501';
    END IF;

    -- Idempotency check: if already RETURNED, return current state
    IF v_handover.status = 'RETURNED' THEN
        RETURN to_jsonb(v_handover);
    END IF;

    -- State machine validation: Only RECEIVED or DISPUTED items can be returned
    IF v_handover.status NOT IN ('RECEIVED', 'DISPUTED') THEN
        RAISE EXCEPTION 'Cannot confirm return: item is in status % (must be in active custody)', v_handover.status
            USING ERRCODE = '23514';
    END IF;

    SELECT COALESCE(NULLIF(trim(full_name), ''), 'Owner')
    INTO v_performer_name
    FROM public.profiles
    WHERE id = v_caller_id;

    IF v_performer_name IS NULL THEN
        v_performer_name := 'Owner';
    END IF;

    -- Authorize internal status update in trigger
    PERFORM set_config('handover.transition_in_progress', 'true', true);

    -- 1. Atomic status update
    UPDATE public.handovers
    SET status = 'RETURNED',
        returned_at = COALESCE(v_handover.returned_at, now()),
        updated_at = now()
    WHERE id = p_handover_id
    RETURNING * INTO v_handover;

    -- 2. Atomic event insert
    INSERT INTO public.handover_events (
        handover_id,
        event_type,
        performed_by,
        metadata,
        created_at
    ) VALUES (
        p_handover_id,
        'RETURNED',
        v_caller_id,
        jsonb_build_object(
            'title', v_performer_name || ' confirmed physical return',
            'performer_name', v_performer_name
        ),
        now()
    );

    PERFORM set_config('handover.transition_in_progress', 'false', true);

    RETURN to_jsonb(v_handover);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

-- 4.3 Cancel / Decline Handover (Owner or Recipient; PENDING -> CANCELLED only)
CREATE OR REPLACE FUNCTION public.cancel_handover(
    p_handover_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS jsonb AS $$
DECLARE
    v_handover public.handovers%ROWTYPE;
    v_caller_id UUID;
    v_caller_email TEXT;
    v_performer_name TEXT;
    v_is_owner BOOLEAN;
    v_is_recipient BOOLEAN;
    v_role_desc TEXT;
BEGIN
    v_caller_id := auth.uid();
    v_caller_email := lower(COALESCE(auth.jwt()->>'email', ''));

    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    -- Lock row FOR UPDATE
    SELECT * INTO v_handover
    FROM public.handovers
    WHERE id = p_handover_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Handover record not found' USING ERRCODE = 'P0002';
    END IF;

    v_is_owner := (v_handover.owner_id = v_caller_id);
    v_is_recipient := (v_handover.recipient_email IS NOT NULL AND lower(v_handover.recipient_email) = v_caller_email);

    IF NOT (v_is_owner OR v_is_recipient) THEN
        RAISE EXCEPTION 'Access denied: caller is not a participant in this handover'
            USING ERRCODE = '42501';
    END IF;

    -- Idempotency check: if already CANCELLED, return current state
    IF v_handover.status = 'CANCELLED' THEN
        RETURN to_jsonb(v_handover);
    END IF;

    -- Strict rule: Cancellation is ONLY permitted while PENDING
    IF v_handover.status <> 'PENDING' THEN
        RAISE EXCEPTION 'Cannot cancel handover in status % (cancellation permitted only while PENDING)', v_handover.status
            USING ERRCODE = '23514';
    END IF;

    SELECT COALESCE(NULLIF(trim(full_name), ''), CASE WHEN v_is_owner THEN 'Sender' ELSE 'Receiver' END)
    INTO v_performer_name
    FROM public.profiles
    WHERE id = v_caller_id;

    v_role_desc := CASE WHEN v_is_owner THEN 'Sender' ELSE 'Receiver' END;

    -- Authorize internal status update in trigger
    PERFORM set_config('handover.transition_in_progress', 'true', true);

    -- 1. Atomic status update
    UPDATE public.handovers
    SET status = 'CANCELLED',
        updated_at = now()
    WHERE id = p_handover_id
    RETURNING * INTO v_handover;

    -- 2. Atomic event insert
    INSERT INTO public.handover_events (
        handover_id,
        event_type,
        performed_by,
        metadata,
        created_at
    ) VALUES (
        p_handover_id,
        'CANCELLED',
        v_caller_id,
        jsonb_build_object(
            'title', 'Handover cancelled by ' || v_role_desc,
            'performer_name', v_performer_name,
            'reason', COALESCE(p_reason, 'No reason provided')
        ),
        now()
    );

    PERFORM set_config('handover.transition_in_progress', 'false', true);

    RETURN to_jsonb(v_handover);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

-- 4.4 Record Condition Issue (Owner or Recipient; RECEIVED -> DISPUTED)
CREATE OR REPLACE FUNCTION public.record_handover_issue(
    p_handover_id UUID,
    p_reason TEXT,
    p_description TEXT
)
RETURNS jsonb AS $$
DECLARE
    v_handover public.handovers%ROWTYPE;
    v_caller_id UUID;
    v_caller_email TEXT;
    v_performer_name TEXT;
BEGIN
    v_caller_id := auth.uid();
    v_caller_email := lower(COALESCE(auth.jwt()->>'email', ''));

    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    -- Lock row FOR UPDATE
    SELECT * INTO v_handover
    FROM public.handovers
    WHERE id = p_handover_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Handover record not found' USING ERRCODE = 'P0002';
    END IF;

    IF v_handover.owner_id <> v_caller_id AND
       (v_handover.recipient_email IS NULL OR lower(v_handover.recipient_email) <> v_caller_email) THEN
        RAISE EXCEPTION 'Access denied: caller is not a participant in this handover'
            USING ERRCODE = '42501';
    END IF;

    -- Strict lifecycle check: Item must be in active RECEIVED custody
    IF v_handover.status <> 'RECEIVED' THEN
        RAISE EXCEPTION 'Cannot record issue for handover in status % (must be in active RECEIVED custody)', v_handover.status
            USING ERRCODE = '23514';
    END IF;

    SELECT COALESCE(NULLIF(trim(full_name), ''), 'Participant')
    INTO v_performer_name
    FROM public.profiles
    WHERE id = v_caller_id;

    -- Authorize internal status update in trigger
    PERFORM set_config('handover.transition_in_progress', 'true', true);

    -- 1. Atomic status update
    UPDATE public.handovers
    SET status = 'DISPUTED',
        updated_at = now()
    WHERE id = p_handover_id
    RETURNING * INTO v_handover;

    -- 2. Atomic event insert
    INSERT INTO public.handover_events (
        handover_id,
        event_type,
        performed_by,
        metadata,
        created_at
    ) VALUES (
        p_handover_id,
        'ISSUE_RECORDED',
        v_caller_id,
        jsonb_build_object(
            'title', v_performer_name || ' recorded a condition issue',
            'performer_name', v_performer_name,
            'reason', p_reason,
            'description', p_description
        ),
        now()
    );

    PERFORM set_config('handover.transition_in_progress', 'false', true);

    RETURN to_jsonb(v_handover);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

-- 4.5 Resolve Condition Issue (Owner or Recipient; DISPUTED -> RECEIVED)
CREATE OR REPLACE FUNCTION public.resolve_handover_issue(
    p_handover_id UUID,
    p_notes TEXT DEFAULT NULL
)
RETURNS jsonb AS $$
DECLARE
    v_handover public.handovers%ROWTYPE;
    v_caller_id UUID;
    v_caller_email TEXT;
    v_performer_name TEXT;
BEGIN
    v_caller_id := auth.uid();
    v_caller_email := lower(COALESCE(auth.jwt()->>'email', ''));

    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    -- Lock row FOR UPDATE
    SELECT * INTO v_handover
    FROM public.handovers
    WHERE id = p_handover_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Handover record not found' USING ERRCODE = 'P0002';
    END IF;

    IF v_handover.owner_id <> v_caller_id AND
       (v_handover.recipient_email IS NULL OR lower(v_handover.recipient_email) <> v_caller_email) THEN
        RAISE EXCEPTION 'Access denied: caller is not a participant in this handover'
            USING ERRCODE = '42501';
    END IF;

    -- Strict lifecycle check: Can ONLY resolve when status is DISPUTED
    IF v_handover.status <> 'DISPUTED' THEN
        RAISE EXCEPTION 'Cannot resolve issue: handover is in status % (must be DISPUTED)', v_handover.status
            USING ERRCODE = '23514';
    END IF;

    SELECT COALESCE(NULLIF(trim(full_name), ''), 'Participant')
    INTO v_performer_name
    FROM public.profiles
    WHERE id = v_caller_id;

    -- Authorize internal status update in trigger
    PERFORM set_config('handover.transition_in_progress', 'true', true);

    -- 1. Atomic status update
    UPDATE public.handovers
    SET status = 'RECEIVED',
        updated_at = now()
    WHERE id = p_handover_id
    RETURNING * INTO v_handover;

    -- 2. Atomic event insert
    INSERT INTO public.handover_events (
        handover_id,
        event_type,
        performed_by,
        metadata,
        created_at
    ) VALUES (
        p_handover_id,
        'ISSUE_RESOLVED',
        v_caller_id,
        jsonb_build_object(
            'title', 'Condition issue resolved by ' || v_performer_name,
            'performer_name', v_performer_name,
            'note', COALESCE(p_notes, 'Issue resolved')
        ),
        now()
    );

    PERFORM set_config('handover.transition_in_progress', 'false', true);

    RETURN to_jsonb(v_handover);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

-- 4.6 Renew Handover Token (STRICTLY Owner only; PENDING -> PENDING with atomic token/event write)
CREATE OR REPLACE FUNCTION public.renew_handover_token(
    p_handover_id UUID,
    p_new_token TEXT
)
RETURNS jsonb AS $$
DECLARE
    v_handover public.handovers%ROWTYPE;
    v_caller_id UUID;
    v_performer_name TEXT;
    v_clean_token TEXT;
    v_meta JSONB;
    v_new_purpose TEXT;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    v_clean_token := trim(COALESCE(p_new_token, ''));
    IF v_clean_token = '' THEN
        RAISE EXCEPTION 'Token cannot be empty' USING ERRCODE = '22023';
    END IF;

    -- Concurrency control: Lock the row FOR UPDATE
    SELECT * INTO v_handover
    FROM public.handovers
    WHERE id = p_handover_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Handover record not found' USING ERRCODE = 'P0002';
    END IF;

    -- Strict owner check: only owner can renew the token
    IF v_handover.owner_id <> v_caller_id THEN
        RAISE EXCEPTION 'Access denied: only the handover owner can renew the confirmation code'
            USING ERRCODE = '42501';
    END IF;

    -- State machine validation: Only PENDING handovers can renew tokens
    IF v_handover.status <> 'PENDING' THEN
        RAISE EXCEPTION 'Cannot renew token: handover is in status % (must be PENDING)', v_handover.status
            USING ERRCODE = '23514';
    END IF;

    -- Token uniqueness check across all other handovers (case-insensitive)
    IF EXISTS (
        SELECT 1 FROM public.handovers
        WHERE lower(trim(token)) = lower(v_clean_token)
          AND id <> p_handover_id
    ) THEN
        RAISE EXCEPTION 'Token % is already in use by another handover', v_clean_token
            USING ERRCODE = '23505';
    END IF;

    SELECT COALESCE(NULLIF(trim(full_name), ''), 'Sender')
    INTO v_performer_name
    FROM public.profiles
    WHERE id = v_caller_id;

    IF v_performer_name IS NULL THEN
        v_performer_name := 'Sender';
    END IF;

    -- Synchronize purpose JSON metadata
    BEGIN
        IF v_handover.purpose IS NOT NULL AND v_handover.purpose ~ '^\s*\{' THEN
            v_meta := v_handover.purpose::jsonb;
            v_meta := jsonb_set(v_meta, '{token}', to_jsonb(v_clean_token));
            v_new_purpose := v_meta::text;
        ELSE
            v_new_purpose := jsonb_build_object('token', v_clean_token, 'note', COALESCE(v_handover.purpose, ''))::text;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        v_new_purpose := jsonb_build_object('token', v_clean_token)::text;
    END;

    -- Authorize internal update
    PERFORM set_config('handover.transition_in_progress', 'true', true);

    -- 1. Atomic update of token and purpose
    UPDATE public.handovers
    SET token = v_clean_token,
        purpose = v_new_purpose,
        updated_at = now()
    WHERE id = p_handover_id
    RETURNING * INTO v_handover;

    -- 2. Atomic event insert (trigger trg_enforce_handover_event_limits will enforce limit)
    INSERT INTO public.handover_events (
        handover_id,
        event_type,
        performed_by,
        metadata,
        created_at
    ) VALUES (
        p_handover_id,
        'CREATED',
        v_caller_id,
        jsonb_build_object(
            'title', 'New confirmation code generated by ' || v_performer_name,
            'performer_name', v_performer_name
        ),
        now()
    );

    PERFORM set_config('handover.transition_in_progress', 'false', true);

    RETURN to_jsonb(v_handover);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

-- ------------------------------------------------------------------------------
-- 5. FUNCTION EXECUTION GRANTS (LEAST PRIVILEGE)
-- ------------------------------------------------------------------------------

REVOKE ALL ON FUNCTION public.confirm_handover_receipt(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.confirm_handover_receipt(UUID) TO authenticated;

REVOKE ALL ON FUNCTION public.confirm_handover_return(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.confirm_handover_return(UUID) TO authenticated;

REVOKE ALL ON FUNCTION public.cancel_handover(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cancel_handover(UUID, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.record_handover_issue(UUID, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_handover_issue(UUID, TEXT, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.resolve_handover_issue(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.resolve_handover_issue(UUID, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.renew_handover_token(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.renew_handover_token(UUID, TEXT) TO authenticated;
