-- ============================================================================
-- VBUS — Harden SECURITY DEFINER RPC functions
--
-- Every conductor-scoped function now derives the caller's identity from
-- auth.uid() (matched against staff_credentials.auth_user_id) instead of
-- trusting client-supplied parameters, and only acts on rows that belong to
-- the caller's own bus. The passenger-facing book_seat derives the passenger
-- from auth.uid() as well. save_translation requires room membership.
--
-- search_path is pinned to '' with fully-qualified table names (Supabase
-- hardening recommendation) so no object shadowing is possible.
-- ============================================================================

-- ── approve_bus_request ─────────────────────────────────────────────────────
-- Old signature (p_responded_by) is replaced: the responding conductor is
-- derived server-side.
DROP FUNCTION IF EXISTS public.approve_bus_request(UUID, UUID);
CREATE OR REPLACE FUNCTION public.approve_bus_request(
  p_request_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_passenger_id UUID;
  v_bus_id       UUID;
  v_staff_id     UUID;
  v_staff_bus    UUID;
BEGIN
  SELECT sc.id, sc.bus_id INTO v_staff_id, v_staff_bus
    FROM public.staff_credentials sc
   WHERE sc.auth_user_id = auth.uid();
  IF v_staff_id IS NULL THEN
    RAISE EXCEPTION 'Not authorized: conductor account required';
  END IF;

  SELECT br.passenger_id, br.bus_id INTO v_passenger_id, v_bus_id
    FROM public.bus_requests br
   WHERE br.id = p_request_id
   FOR UPDATE;
  IF v_bus_id IS NULL OR v_bus_id <> v_staff_bus THEN
    RAISE EXCEPTION 'Not authorized: request does not belong to your bus';
  END IF;

  UPDATE public.bus_requests
     SET status        = 'approved',
         responded_at  = now(),
         responded_by  = v_staff_id
   WHERE id = p_request_id;

  UPDATE public.passengers
     SET bus_id          = v_bus_id,
         approval_status = 'approved',
         approved_by     = v_staff_id,
         approved_at     = now()
   WHERE id = v_passenger_id;
END;
$$;

-- ── reject_bus_request ─────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.reject_bus_request(UUID, UUID, TEXT);
CREATE OR REPLACE FUNCTION public.reject_bus_request(
  p_request_id UUID,
  p_reason     TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_passenger_id UUID;
  v_bus_id       UUID;
  v_staff_id     UUID;
  v_staff_bus    UUID;
BEGIN
  SELECT sc.id, sc.bus_id INTO v_staff_id, v_staff_bus
    FROM public.staff_credentials sc
   WHERE sc.auth_user_id = auth.uid();
  IF v_staff_id IS NULL THEN
    RAISE EXCEPTION 'Not authorized: conductor account required';
  END IF;

  SELECT br.passenger_id, br.bus_id INTO v_passenger_id, v_bus_id
    FROM public.bus_requests br
   WHERE br.id = p_request_id
   FOR UPDATE;
  IF v_bus_id IS NULL OR v_bus_id <> v_staff_bus THEN
    RAISE EXCEPTION 'Not authorized: request does not belong to your bus';
  END IF;

  UPDATE public.bus_requests
     SET status           = 'rejected',
         responded_at     = now(),
         responded_by     = v_staff_id,
         rejection_reason = p_reason
   WHERE id = p_request_id;

  UPDATE public.passengers
     SET approval_status  = 'rejected',
         rejection_reason = p_reason
   WHERE id = v_passenger_id;
END;
$$;

-- ── remove_passenger ───────────────────────────────────────────────────────
-- Conductor removes a passenger from THEIR OWN bus only.
CREATE OR REPLACE FUNCTION public.remove_passenger(
  p_passenger_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_staff_bus UUID;
  v_pass_bus  UUID;
BEGIN
  SELECT sc.bus_id INTO v_staff_bus
    FROM public.staff_credentials sc
   WHERE sc.auth_user_id = auth.uid();
  IF v_staff_bus IS NULL THEN
    RAISE EXCEPTION 'Not authorized: conductor account required';
  END IF;

  SELECT p.bus_id INTO v_pass_bus
    FROM public.passengers p
   WHERE p.id = p_passenger_id;
  IF v_pass_bus IS NULL OR v_pass_bus <> v_staff_bus THEN
    RAISE EXCEPTION 'Not authorized: passenger is not on your bus';
  END IF;

  DELETE FROM public.seat_bookings
   WHERE passenger_id = p_passenger_id
     AND booking_date >= CURRENT_DATE;

  UPDATE public.passengers
     SET approval_status  = 'rejected',
         bus_id           = NULL
   WHERE id = p_passenger_id;
END;
$$;

-- ── approve_seat_reservation ───────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.approve_seat_reservation(UUID, UUID);
CREATE OR REPLACE FUNCTION public.approve_seat_reservation(
  p_reservation_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_staff_id  UUID;
  v_staff_bus UUID;
BEGIN
  SELECT sc.id, sc.bus_id INTO v_staff_id, v_staff_bus
    FROM public.staff_credentials sc
   WHERE sc.auth_user_id = auth.uid();
  IF v_staff_id IS NULL THEN
    RAISE EXCEPTION 'Not authorized: conductor account required';
  END IF;

  UPDATE public.seat_reservations sr
     SET status        = 'approved',
         responded_at  = now(),
         responded_by  = v_staff_id
   WHERE sr.id = p_reservation_id
     AND sr.bus_id = v_staff_bus;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Not authorized: reservation does not belong to your bus';
  END IF;
END;
$$;

-- ── reject_seat_reservation ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.reject_seat_reservation(UUID, UUID, TEXT);
CREATE OR REPLACE FUNCTION public.reject_seat_reservation(
  p_reservation_id UUID,
  p_reason         TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_staff_id  UUID;
  v_staff_bus UUID;
BEGIN
  SELECT sc.id, sc.bus_id INTO v_staff_id, v_staff_bus
    FROM public.staff_credentials sc
   WHERE sc.auth_user_id = auth.uid();
  IF v_staff_id IS NULL THEN
    RAISE EXCEPTION 'Not authorized: conductor account required';
  END IF;

  UPDATE public.seat_reservations sr
     SET status           = 'rejected',
         responded_at     = now(),
         responded_by     = v_staff_id,
         rejection_reason = p_reason
   WHERE sr.id = p_reservation_id
     AND sr.bus_id = v_staff_bus;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Not authorized: reservation does not belong to your bus';
  END IF;
END;
$$;

-- ── remove_seat_reservation ────────────────────────────────────────────────
-- Conductor force-removes a reservation on THEIR OWN bus only.
CREATE OR REPLACE FUNCTION public.remove_seat_reservation(
  p_reservation_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_staff_bus UUID;
BEGIN
  SELECT sc.bus_id INTO v_staff_bus
    FROM public.staff_credentials sc
   WHERE sc.auth_user_id = auth.uid();
  IF v_staff_bus IS NULL THEN
    RAISE EXCEPTION 'Not authorized: conductor account required';
  END IF;

  DELETE FROM public.seat_reservations sr
   WHERE sr.id = p_reservation_id
     AND sr.bus_id = v_staff_bus;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Not authorized: reservation does not belong to your bus';
  END IF;
END;
$$;

-- ── book_seat ──────────────────────────────────────────────────────────────
-- The passenger is derived from auth.uid(); the caller must be an approved
-- passenger assigned to the bus they are booking for.
DROP FUNCTION IF EXISTS public.book_seat(UUID, UUID, INTEGER, DATE);
CREATE OR REPLACE FUNCTION public.book_seat(
  p_bus_id       UUID,
  p_seat_number  INTEGER,
  p_booking_date DATE
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.passengers p
     WHERE p.id = auth.uid()
       AND p.bus_id = p_bus_id
       AND p.approval_status = 'approved'
  ) THEN
    RAISE EXCEPTION 'Not authorized: only approved passengers of this bus can book seats';
  END IF;

  INSERT INTO public.seat_bookings (bus_id, passenger_id, seat_number, booking_date)
  VALUES (p_bus_id, auth.uid(), p_seat_number, p_booking_date);
END;
$$;

-- ── save_translation ───────────────────────────────────────────────────────
-- Caller must be a member of the message's room: a passenger on the room's
-- bus, the room's direct passenger, or the bus's conductor.
CREATE OR REPLACE FUNCTION public.save_translation(
  p_message_id    UUID,
  p_language_code TEXT,
  p_translated    TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_current JSONB;
BEGIN
  IF NOT EXISTS (
    SELECT 1
      FROM public.messages m
      JOIN public.chat_rooms r ON r.id = m.chat_room_id
     WHERE m.id = p_message_id
       AND (
             (r.room_type = 'broadcast' AND (
                EXISTS (SELECT 1 FROM public.passengers p
                         WHERE p.id = auth.uid() AND p.bus_id = r.bus_id)
             OR EXISTS (SELECT 1 FROM public.staff_credentials s
                         WHERE s.auth_user_id = auth.uid() AND s.bus_id = r.bus_id)
             ))
          OR (r.room_type = 'direct' AND (
                r.passenger_id = auth.uid()
             OR EXISTS (SELECT 1 FROM public.staff_credentials s
                         WHERE s.auth_user_id = auth.uid() AND s.bus_id = r.bus_id)
             ))
           )
  ) THEN
    RAISE EXCEPTION 'Not authorized: not a member of this room';
  END IF;

  SELECT COALESCE(m.translations, '{}'::jsonb) INTO v_current
    FROM public.messages m
   WHERE m.id = p_message_id;

  v_current = v_current || jsonb_build_object(p_language_code, p_translated);

  UPDATE public.messages
     SET translations = v_current
   WHERE id = p_message_id;
END;
$$;

-- ── demo_advance_bus ───────────────────────────────────────────────────────
-- Demo cron still runs it (as the job owner), but the public can no longer
-- move live bus locations via PostgREST.
REVOKE EXECUTE ON FUNCTION public.demo_advance_bus() FROM anon, authenticated;
