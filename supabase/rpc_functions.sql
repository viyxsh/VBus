-- ============================================================================
-- VBUS — SECURITY DEFINER RPC functions to bypass RLS
--
-- Run this in the Supabase SQL Editor once.
-- These functions run with the privileges of the function creator (typically
-- the database owner / service_role), bypassing row-level security so that
-- conductors can approve / reject passenger requests even though they do not
-- own the passenger row.
-- ============================================================================

-- ── approve_bus_request ─────────────────────────────────────────────────────
-- Approves a bus join request: sets bus_requests.status → 'approved' and
-- updates the passenger's bus_id, approval_status, approved_by, approved_at.
CREATE OR REPLACE FUNCTION approve_bus_request(
  p_request_id  UUID,
  p_responded_by UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_passenger_id UUID;
  v_bus_id       UUID;
BEGIN
  SELECT passenger_id, bus_id INTO v_passenger_id, v_bus_id
    FROM bus_requests
   WHERE id = p_request_id;

  UPDATE bus_requests
     SET status        = 'approved',
         responded_at  = now(),
         responded_by  = p_responded_by
   WHERE id = p_request_id;

  UPDATE passengers
     SET bus_id          = v_bus_id,
         approval_status = 'approved',
         approved_by     = p_responded_by,
         approved_at     = now()
   WHERE id = v_passenger_id;
END;
$$;

-- ── reject_bus_request ─────────────────────────────────────────────────────
-- Rejects a bus join request: sets bus_requests.status → 'rejected' and
-- updates the passenger's approval_status and rejection_reason.
CREATE OR REPLACE FUNCTION reject_bus_request(
  p_request_id   UUID,
  p_responded_by UUID,
  p_reason       TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_passenger_id UUID;
BEGIN
  SELECT passenger_id INTO v_passenger_id
    FROM bus_requests
   WHERE id = p_request_id;

  UPDATE bus_requests
     SET status           = 'rejected',
         responded_at     = now(),
         responded_by     = p_responded_by,
         rejection_reason = p_reason
   WHERE id = p_request_id;

  UPDATE passengers
     SET approval_status  = 'rejected',
         rejection_reason = p_reason
   WHERE id = v_passenger_id;
END;
$$;

-- ── remove_passenger ───────────────────────────────────────────────────────
-- Conductor removes a passenger from a bus: clears bus_id, sets status to
-- rejected, and deletes future seat_bookings.
CREATE OR REPLACE FUNCTION remove_passenger(
  p_passenger_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM seat_bookings
   WHERE passenger_id = p_passenger_id
     AND booking_date >= CURRENT_DATE;

  UPDATE passengers
     SET approval_status  = 'rejected',
         bus_id           = NULL
   WHERE id = p_passenger_id;
END;
$$;

-- ── approve_seat_reservation ───────────────────────────────────────────────
-- Conductor approves a permanent seat reservation.
CREATE OR REPLACE FUNCTION approve_seat_reservation(
  p_reservation_id UUID,
  p_responded_by   UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE seat_reservations
     SET status        = 'approved',
         responded_at  = now(),
         responded_by  = p_responded_by
   WHERE id = p_reservation_id;
END;
$$;

-- ── reject_seat_reservation ────────────────────────────────────────────────
-- Conductor rejects a permanent seat reservation.
CREATE OR REPLACE FUNCTION reject_seat_reservation(
  p_reservation_id UUID,
  p_responded_by   UUID,
  p_reason         TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE seat_reservations
     SET status           = 'rejected',
         responded_at     = now(),
         responded_by     = p_responded_by,
         rejection_reason = p_reason
   WHERE id = p_reservation_id;
END;
$$;

-- ── remove_reservation ────────────────────────────────────────────────────
-- Conductor removes / deletes a seat reservation (force-unreserve).
CREATE OR REPLACE FUNCTION remove_seat_reservation(
  p_reservation_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM seat_reservations WHERE id = p_reservation_id;
END;
$$;

-- ── book_seat ──────────────────────────────────────────────────────────────
-- Passenger books a seat for a given date.
CREATE OR REPLACE FUNCTION book_seat(
  p_bus_id       UUID,
  p_passenger_id UUID,
  p_seat_number  INTEGER,
  p_booking_date DATE
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO seat_bookings (bus_id, passenger_id, seat_number, booking_date)
  VALUES (p_bus_id, p_passenger_id, p_seat_number, p_booking_date);
END;
$$;

-- ── save_translation ─────────────────────────────────────────────────────────
-- Stores a translated text for a message so every room member can see it.
CREATE OR REPLACE FUNCTION save_translation(
  p_message_id    UUID,
  p_language_code TEXT,
  p_translated    TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current JSONB;
BEGIN
  SELECT COALESCE(translations, '{}'::jsonb) INTO v_current
    FROM messages
   WHERE id = p_message_id;

  v_current = v_current || jsonb_build_object(p_language_code, p_translated);

  UPDATE messages
     SET translations = v_current
   WHERE id = p_message_id;
END;
$$;
