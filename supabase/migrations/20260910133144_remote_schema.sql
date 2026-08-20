SET local check_function_bodies = off;

CREATE EXTENSION "pg_cron";

CREATE EXTENSION "unaccent" SCHEMA "extensions";

CREATE TABLE "public"."admin_audit_log" (
  "id"           uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "actor_email"  text                     NOT NULL,
  "action"       text                     NOT NULL,
  "target_table" text                     NOT NULL,
  "target_id"    text,
  "details"      jsonb,
  "created_at"   timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "admin_audit_log_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."admin_audit_log"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."attendance" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "trip_id"         uuid                     NOT NULL,
  "passenger_id"    uuid                     NOT NULL,
  "stop_id"         uuid                     NOT NULL,
  "state"           text                     NOT NULL DEFAULT 'waiting'::text,
  "scanned_at"      timestamp with time zone,
  "overridden_by"   uuid,
  "override_reason" text,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "attendance_pkey" PRIMARY KEY (id),
  CONSTRAINT "attendance_state_check" CHECK ((state = ANY (ARRAY['waiting'::text, 'present'::text, 'missing'::text, 'absent'::text]))),
  CONSTRAINT "attendance_trip_id_passenger_id_key" UNIQUE (trip_id, passenger_id)
);

ALTER TABLE "public"."attendance"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."bus_locations" (
  "bus_id"     uuid                     NOT NULL,
  "trip_id"    uuid,
  "latitude"   numeric(10,7)            NOT NULL,
  "longitude"  numeric(10,7)            NOT NULL,
  "heading"    numeric(5,2),
  "speed_kmh"  numeric(5,2),
  "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "bus_locations_pkey" PRIMARY KEY (bus_id)
);

ALTER TABLE "public"."bus_locations"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."bus_requests" (
  "id"               uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "passenger_id"     uuid                     NOT NULL,
  "bus_id"           uuid                     NOT NULL,
  "status"           character varying(20)    NOT NULL DEFAULT 'pending'::character varying,
  "request_type"     character varying(20)    NOT NULL DEFAULT 'join'::character varying,
  "requested_at"     timestamp with time zone NOT NULL DEFAULT now(),
  "responded_at"     timestamp with time zone,
  "responded_by"     uuid,
  "rejection_reason" text,
  "created_at"       timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "bus_requests_pkey" PRIMARY KEY (id),
  CONSTRAINT "bus_requests_request_type_check"
    CHECK (((request_type)::text = ANY ((ARRAY['join'::character varying, 'leave'::character varying, 'change'::character varying])::text[]))),
  CONSTRAINT "bus_requests_status_check"
    CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'approved'::character varying, 'rejected'::character varying])::text[])))
);

ALTER TABLE "public"."bus_requests"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."bus_stops" (
  "id"            uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "route_id"      uuid                     NOT NULL,
  "name"          text                     NOT NULL,
  "latitude"      numeric(10,7)            NOT NULL,
  "longitude"     numeric(10,7)            NOT NULL,
  "stop_order"    integer                  NOT NULL,
  "created_at"    timestamp with time zone NOT NULL DEFAULT now(),
  "time_to_vit"   time without time zone,
  "time_from_vit" time without time zone,
  CONSTRAINT "bus_stops_pkey" PRIMARY KEY (id),
  CONSTRAINT "bus_stops_route_id_name_key" UNIQUE (route_id, name),
  CONSTRAINT "bus_stops_route_id_stop_order_key" UNIQUE (route_id, stop_order)
);

ALTER TABLE "public"."bus_stops"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."buses" (
  "id"                          uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "bus_number"                  text                     NOT NULL,
  "city_id"                     uuid                     NOT NULL,
  "route_id"                    uuid                     NOT NULL,
  "total_seats"                 integer                  NOT NULL,
  "student_seats"               integer                  NOT NULL,
  "faculty_seats"               integer                  NOT NULL,
  "is_active"                   boolean                  NOT NULL DEFAULT true,
  "created_at"                  timestamp with time zone NOT NULL DEFAULT now(),
  "left_seats"                  integer                  NOT NULL DEFAULT 18,
  "faculty_reserved_rows_left"  integer                  NOT NULL DEFAULT 0,
  "faculty_reserved_rows_right" integer                  NOT NULL DEFAULT 0,
  CONSTRAINT "buses_bus_number_key" UNIQUE (bus_number),
  CONSTRAINT "buses_faculty_seats_check" CHECK ((faculty_seats >= 0)),
  CONSTRAINT "buses_pkey" PRIMARY KEY (id),
  CONSTRAINT "buses_student_seats_check" CHECK ((student_seats >= 0)),
  CONSTRAINT "buses_total_seats_check" CHECK ((total_seats > 0)),
  CONSTRAINT "seats_add_up" CHECK (((student_seats + faculty_seats) = total_seats))
);

ALTER TABLE "public"."buses"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."chat_room_reads" (
  "user_id"      uuid                     NOT NULL,
  "chat_room_id" uuid                     NOT NULL,
  "last_read_at" timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "chat_room_reads_pkey" PRIMARY KEY (user_id, chat_room_id)
);

ALTER TABLE "public"."chat_room_reads"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."chat_rooms" (
  "id"           uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "bus_id"       uuid                     NOT NULL,
  "created_at"   timestamp with time zone NOT NULL DEFAULT now(),
  "room_type"    text                     NOT NULL DEFAULT 'broadcast'::text,
  "passenger_id" uuid,
  CONSTRAINT "chat_rooms_pkey" PRIMARY KEY (id),
  CONSTRAINT "chat_rooms_room_type_check" CHECK ((room_type = ANY (ARRAY['broadcast'::text, 'direct'::text])))
);

ALTER TABLE "public"."chat_rooms"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."cities" (
  "id"         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "name"       text                     NOT NULL,
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "cities_name_key" UNIQUE (name),
  CONSTRAINT "cities_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."cities"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."custom_pins" (
  "id"                    uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "passenger_id"          uuid                     NOT NULL,
  "bus_id"                uuid                     NOT NULL,
  "label"                 text                     NOT NULL,
  "latitude"              numeric                  NOT NULL,
  "longitude"             numeric                  NOT NULL,
  "notify_minutes_before" integer                  NOT NULL DEFAULT 5,
  "notified_at"           timestamp with time zone,
  "created_at"            timestamp with time zone DEFAULT now(),
  CONSTRAINT "custom_pins_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."custom_pins"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."message_reads" (
  "message_id" uuid                     NOT NULL,
  "user_id"    uuid                     NOT NULL,
  "read_at"    timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "message_reads_pkey" PRIMARY KEY (message_id, user_id)
);

ALTER TABLE "public"."message_reads"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."messages" (
  "id"             uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "chat_room_id"   uuid                     NOT NULL,
  "sender_id"      uuid                     NOT NULL,
  "sender_name"    text                     NOT NULL,
  "type"           text                     NOT NULL,
  "content"        text,
  "audio_url"      text,
  "audio_duration" integer,
  "sent_at"        timestamp with time zone NOT NULL DEFAULT now(),
  "translations"   jsonb                    DEFAULT '{}'::jsonb,
  CONSTRAINT "messages_check1" CHECK (((type = 'text'::text) OR (audio_url IS NOT NULL))),
  CONSTRAINT "messages_check" CHECK (((type = 'voice'::text) OR (content IS NOT NULL))),
  CONSTRAINT "messages_pkey" PRIMARY KEY (id),
  CONSTRAINT "messages_type_check" CHECK ((type = ANY (ARRAY['text'::text, 'voice'::text])))
);

ALTER TABLE "public"."messages"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."passengers" (
  "id"               uuid                     NOT NULL,
  "name"             text                     NOT NULL,
  "institute_id"     text                     NOT NULL,
  "email"            text                     NOT NULL,
  "phone"            text,
  "user_type"        text                     NOT NULL,
  "city_id"          uuid                     NOT NULL,
  "bus_id"           uuid,
  "stop_id"          uuid                     NOT NULL,
  "approval_status"  text                     NOT NULL DEFAULT 'pending'::text,
  "receipt_url"      text,
  "rejection_reason" text,
  "approved_by"      uuid,
  "approved_at"      timestamp with time zone,
  "created_at"       timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "passengers_approval_status_check" CHECK ((approval_status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text]))),
  CONSTRAINT "passengers_email_key" UNIQUE (email),
  CONSTRAINT "passengers_institute_id_key" UNIQUE (institute_id),
  CONSTRAINT "passengers_pkey" PRIMARY KEY (id),
  CONSTRAINT "passengers_user_type_check" CHECK ((user_type = ANY (ARRAY['student'::text, 'faculty'::text]))),
  CONSTRAINT "vitbhopal_email" CHECK ((email ~* '@vitbhopal\.ac\.in$'::text))
);

ALTER TABLE "public"."passengers"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."routes" (
  "id"         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "city_id"    uuid                     NOT NULL,
  "name"       text                     NOT NULL,
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "routes_city_id_name_key" UNIQUE (city_id, name),
  CONSTRAINT "routes_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."routes"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."seat_bookings" (
  "id"           uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "bus_id"       uuid                     NOT NULL,
  "passenger_id" uuid                     NOT NULL,
  "seat_number"  integer                  NOT NULL,
  "booking_date" date                     NOT NULL DEFAULT CURRENT_DATE,
  "booked_at"    timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "seat_bookings_bus_id_passenger_id_booking_date_key" UNIQUE (bus_id, passenger_id, booking_date),
  CONSTRAINT "seat_bookings_bus_id_seat_number_booking_date_key" UNIQUE (bus_id, seat_number, booking_date),
  CONSTRAINT "seat_bookings_pkey" PRIMARY KEY (id),
  CONSTRAINT "seat_bookings_seat_number_check" CHECK ((seat_number > 0)),
  CONSTRAINT "seat_bookings_unique_seat" UNIQUE (bus_id, seat_number, booking_date)
);

ALTER TABLE "public"."seat_bookings"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."seat_reservations" (
  "id"               uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "bus_id"           uuid                     NOT NULL,
  "passenger_id"     uuid                     NOT NULL,
  "seat_number"      integer                  NOT NULL,
  "status"           text                     NOT NULL DEFAULT 'pending'::text,
  "requested_at"     timestamp with time zone NOT NULL DEFAULT now(),
  "responded_at"     timestamp with time zone,
  "responded_by"     uuid,
  "rejection_reason" text,
  CONSTRAINT "seat_reservations_bus_id_passenger_id_key" UNIQUE (bus_id, passenger_id),
  CONSTRAINT "seat_reservations_pkey" PRIMARY KEY (id),
  CONSTRAINT "seat_reservations_status_check" CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])))
);

ALTER TABLE "public"."seat_reservations"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."staff_credentials" (
  "id"           uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "auth_user_id" uuid                     NOT NULL,
  "username"     text                     NOT NULL,
  "role"         text                     NOT NULL,
  "bus_id"       uuid                     NOT NULL,
  "display_name" text,
  "is_active"    boolean                  NOT NULL DEFAULT true,
  "created_at"   timestamp with time zone NOT NULL DEFAULT now(),
  "phone"        text,
  CONSTRAINT "staff_credentials_auth_user_id_key" UNIQUE (auth_user_id),
  CONSTRAINT "staff_credentials_pkey" PRIMARY KEY (id),
  CONSTRAINT "staff_credentials_role_check" CHECK ((role = 'conductor'::text)),
  CONSTRAINT "staff_credentials_username_key" UNIQUE (username)
);

ALTER TABLE "public"."staff_credentials"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."trips" (
  "id"                 uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "bus_id"             uuid                     NOT NULL,
  "conductor_id"       uuid                     NOT NULL,
  "driver_id"          uuid,
  "state"              text                     NOT NULL DEFAULT 'not_started'::text,
  "trip_date"          date                     NOT NULL DEFAULT CURRENT_DATE,
  "started_at"         timestamp with time zone,
  "ended_at"           timestamp with time zone,
  "current_stop_index" integer                  NOT NULL DEFAULT 0,
  "created_at"         timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "trips_pkey" PRIMARY KEY (id),
  CONSTRAINT "trips_state_check" CHECK ((state = ANY (ARRAY['not_started'::text, 'ongoing'::text, 'ended'::text])))
);

ALTER TABLE "public"."trips"
  ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.approve_bus_request (
  p_request_id   uuid,
  p_responded_by uuid
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.approve_seat_reservation (
  p_reservation_id uuid,
  p_responded_by   uuid
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
BEGIN
  UPDATE seat_reservations
     SET status        = 'approved',
         responded_at  = now(),
         responded_by  = p_responded_by
   WHERE id = p_reservation_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.book_seat (
  p_bus_id       uuid,
  p_passenger_id uuid,
  p_seat_number  integer,
  p_booking_date date
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
BEGIN
  INSERT INTO seat_bookings (bus_id, passenger_id, seat_number, booking_date)
  VALUES (p_bus_id, p_passenger_id, p_seat_number, p_booking_date);
END;
$function$;

CREATE OR REPLACE FUNCTION public.check_route_belongs_to_city()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.routes r
    WHERE r.id = NEW.route_id AND r.city_id = NEW.city_id
  ) THEN
    RAISE EXCEPTION 'Route % does not belong to city %', NEW.route_id, NEW.city_id;
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.demo_advance_bus()
  RETURNS void
  LANGUAGE plpgsql
  AS $function$
declare
  v_email text := 'demo.23bce10001@vitbhopal.ac.in';  -- <-- set to DEMO_STUDENT_EMAIL
  v_bus uuid; v_route uuid; v_trip uuid; v_idx int; v_n int;
  cur_lat numeric; cur_lng numeric; tgt_lat numeric; tgt_lng numeric;
begin
  select p.bus_id, b.route_id into v_bus, v_route
    from passengers p join buses b on b.id = p.bus_id
   where lower(p.email) = lower(v_email) limit 1;
  if v_bus is null then return; end if;

  select id, current_stop_index into v_trip, v_idx
    from trips
   where bus_id = v_bus and trip_date = current_date and state = 'ongoing'
   order by created_at desc limit 1;
  if v_trip is null then return; end if;

  select count(*) into v_n from bus_stops where route_id = v_route;
  select latitude, longitude into cur_lat, cur_lng from bus_locations where bus_id = v_bus;
  if cur_lat is null then return; end if;

  -- Target = the stop after the current index (clamped to the last stop).
  select latitude, longitude into tgt_lat, tgt_lng
    from bus_stops where route_id = v_route order by stop_order
   offset least(v_idx + 1, v_n - 1) limit 1;

  cur_lat := cur_lat + (tgt_lat - cur_lat) * 0.25;
  cur_lng := cur_lng + (tgt_lng - cur_lng) * 0.25;

  update bus_locations
     set latitude = cur_lat, longitude = cur_lng,
         speed_kmh = 28, heading = 0, updated_at = now()
   where bus_id = v_bus;

  -- Arrived at the target stop?
  if abs(tgt_lat - cur_lat) < 0.0006 and abs(tgt_lng - cur_lng) < 0.0006 then
    if v_idx + 1 >= v_n - 1 then
      -- End of route → loop back to the first stop.
      update trips set current_stop_index = 0 where id = v_trip;
      select latitude, longitude into cur_lat, cur_lng
        from bus_stops where route_id = v_route order by stop_order limit 1;
      update bus_locations set latitude = cur_lat, longitude = cur_lng, updated_at = now()
       where bus_id = v_bus;
    else
      update trips set current_stop_index = v_idx + 1 where id = v_trip;
    end if;
  end if;
end $function$;

CREATE OR REPLACE FUNCTION public.detect_user_type (
  email text
)
  RETURNS text
  LANGUAGE plpgsql
  IMMUTABLE
  AS $function$
BEGIN
  -- Student: firstname.YYBBBnnnnn@vitbhopal.ac.in
  -- e.g. viya.23bce11351@vitbhopal.ac.in
  IF email ~* '^[a-z]+\.[0-9]{2}[a-z]{3}[0-9]{5}@vitbhopal\.ac\.in$' THEN
    RETURN 'student';
  ELSE
    RETURN 'faculty';
  END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.finalize_trip_attendance (
  p_trip_id uuid
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
BEGIN
  UPDATE public.attendance
  SET state = 'absent'
  WHERE trip_id = p_trip_id
    AND state = 'waiting';
END;
$function$;

CREATE OR REPLACE FUNCTION public.initialize_trip_attendance (
  p_trip_id uuid
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
DECLARE
  v_bus_id uuid;
BEGIN
  SELECT bus_id INTO v_bus_id FROM public.trips WHERE id = p_trip_id;

  INSERT INTO public.attendance (trip_id, passenger_id, stop_id)
  SELECT p_trip_id, p.id, p.stop_id
  FROM public.passengers p
  WHERE p.bus_id = v_bus_id
    AND p.approval_status = 'approved'
  ON CONFLICT (trip_id, passenger_id) DO NOTHING;
END;
$function$;

CREATE OR REPLACE FUNCTION public.reject_bus_request (
  p_request_id   uuid,
  p_responded_by uuid,
  p_reason       text DEFAULT NULL::text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.reject_seat_reservation (
  p_reservation_id uuid,
  p_responded_by   uuid,
  p_reason         text DEFAULT NULL::text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
BEGIN
  UPDATE seat_reservations
     SET status           = 'rejected',
         responded_at     = now(),
         responded_by     = p_responded_by,
         rejection_reason = p_reason
   WHERE id = p_reservation_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.remove_passenger (
  p_passenger_id uuid
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
BEGIN
  DELETE FROM seat_bookings
   WHERE passenger_id = p_passenger_id
     AND booking_date >= CURRENT_DATE;

  UPDATE passengers
     SET approval_status  = 'rejected',
         bus_id           = NULL
   WHERE id = p_passenger_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.remove_seat_reservation (
  p_reservation_id uuid
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
BEGIN
  DELETE FROM seat_reservations WHERE id = p_reservation_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.rls_auto_enable()
  RETURNS event_trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'pg_catalog'
  AS $function$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$function$;

CREATE OR REPLACE FUNCTION public.save_translation (
  p_message_id    uuid,
  p_language_code text,
  p_translated    text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.update_faculty_rows (
  p_bus_id     uuid,
  p_rows_left  integer,
  p_rows_right integer
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_result JSONB;
BEGIN
  UPDATE buses
  SET faculty_reserved_rows_left  = p_rows_left,
      faculty_reserved_rows_right = p_rows_right
  WHERE id = p_bus_id
  RETURNING jsonb_build_object(
    'id', id,
    'faculty_reserved_rows_left', faculty_reserved_rows_left,
    'faculty_reserved_rows_right', faculty_reserved_rows_right
  ) INTO v_result;

  RETURN v_result;
END;
$function$;

ALTER TABLE "public"."attendance"
  ADD CONSTRAINT "attendance_stop_id_fkey" FOREIGN KEY (stop_id) REFERENCES public.bus_stops(id);

ALTER TABLE "public"."bus_locations"
  ADD CONSTRAINT "bus_locations_bus_id_fkey" FOREIGN KEY (bus_id) REFERENCES public.buses(id);

ALTER TABLE "public"."bus_requests"
  ADD CONSTRAINT "bus_requests_bus_id_fkey" FOREIGN KEY (bus_id) REFERENCES public.buses(id);

ALTER TABLE "public"."chat_room_reads"
  ADD CONSTRAINT "chat_room_reads_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE "public"."chat_rooms"
  ADD CONSTRAINT "chat_rooms_bus_id_fkey" FOREIGN KEY (bus_id) REFERENCES public.buses(id) ON DELETE CASCADE;

ALTER TABLE "public"."chat_room_reads"
  ADD CONSTRAINT "chat_room_reads_chat_room_id_fkey" FOREIGN KEY (chat_room_id) REFERENCES public.chat_rooms(id) ON DELETE CASCADE;

ALTER TABLE "public"."buses"
  ADD CONSTRAINT "buses_city_id_fkey" FOREIGN KEY (city_id) REFERENCES public.cities(id) ON DELETE RESTRICT;

ALTER TABLE "public"."custom_pins"
  ADD CONSTRAINT "custom_pins_bus_id_fkey" FOREIGN KEY (bus_id) REFERENCES public.buses(id);

ALTER TABLE "public"."custom_pins"
  ADD CONSTRAINT "custom_pins_passenger_id_fkey" FOREIGN KEY (passenger_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE "public"."message_reads"
  ADD CONSTRAINT "message_reads_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id);

ALTER TABLE "public"."messages"
  ADD CONSTRAINT "messages_chat_room_id_fkey" FOREIGN KEY (chat_room_id) REFERENCES public.chat_rooms(id) ON DELETE CASCADE;

ALTER TABLE "public"."message_reads"
  ADD CONSTRAINT "message_reads_message_id_fkey" FOREIGN KEY (message_id) REFERENCES public.messages(id) ON DELETE CASCADE;

ALTER TABLE "public"."messages"
  ADD CONSTRAINT "messages_sender_id_fkey" FOREIGN KEY (sender_id) REFERENCES auth.users(id);

ALTER TABLE "public"."passengers"
  ADD CONSTRAINT "passengers_bus_id_fkey" FOREIGN KEY (bus_id) REFERENCES public.buses(id);

ALTER TABLE "public"."passengers"
  ADD CONSTRAINT "passengers_city_id_fkey" FOREIGN KEY (city_id) REFERENCES public.cities(id);

ALTER TABLE "public"."passengers"
  ADD CONSTRAINT "passengers_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE "public"."attendance"
  ADD CONSTRAINT "attendance_passenger_id_fkey" FOREIGN KEY (passenger_id) REFERENCES public.passengers(id);

ALTER TABLE "public"."bus_requests"
  ADD CONSTRAINT "bus_requests_passenger_id_fkey" FOREIGN KEY (passenger_id) REFERENCES public.passengers(id) ON DELETE CASCADE;

ALTER TABLE "public"."chat_rooms"
  ADD CONSTRAINT "chat_rooms_passenger_id_fkey" FOREIGN KEY (passenger_id) REFERENCES public.passengers(id);

ALTER TABLE "public"."passengers"
  ADD CONSTRAINT "passengers_stop_id_fkey" FOREIGN KEY (stop_id) REFERENCES public.bus_stops(id);

ALTER TABLE "public"."routes"
  ADD CONSTRAINT "routes_city_id_fkey" FOREIGN KEY (city_id) REFERENCES public.cities(id) ON DELETE RESTRICT;

ALTER TABLE "public"."bus_stops"
  ADD CONSTRAINT "bus_stops_route_id_fkey" FOREIGN KEY (route_id) REFERENCES public.routes(id) ON DELETE CASCADE;

ALTER TABLE "public"."buses"
  ADD CONSTRAINT "buses_route_id_fkey" FOREIGN KEY (route_id) REFERENCES public.routes(id) ON DELETE RESTRICT;

ALTER TABLE "public"."seat_bookings"
  ADD CONSTRAINT "seat_bookings_bus_id_fkey" FOREIGN KEY (bus_id) REFERENCES public.buses(id);

ALTER TABLE "public"."seat_bookings"
  ADD CONSTRAINT "seat_bookings_passenger_id_fkey" FOREIGN KEY (passenger_id) REFERENCES public.passengers(id);

ALTER TABLE "public"."seat_reservations"
  ADD CONSTRAINT "seat_reservations_bus_id_fkey" FOREIGN KEY (bus_id) REFERENCES public.buses(id);

ALTER TABLE "public"."seat_reservations"
  ADD CONSTRAINT "seat_reservations_passenger_id_fkey" FOREIGN KEY (passenger_id) REFERENCES public.passengers(id);

ALTER TABLE "public"."staff_credentials"
  ADD CONSTRAINT "staff_credentials_auth_user_id_fkey" FOREIGN KEY (auth_user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE "public"."staff_credentials"
  ADD CONSTRAINT "staff_credentials_bus_id_fkey" FOREIGN KEY (bus_id) REFERENCES public.buses(id) ON DELETE RESTRICT;

ALTER TABLE "public"."attendance"
  ADD CONSTRAINT "attendance_overridden_by_fkey" FOREIGN KEY (overridden_by) REFERENCES public.staff_credentials(id);

ALTER TABLE "public"."bus_requests"
  ADD CONSTRAINT "bus_requests_responded_by_fkey" FOREIGN KEY (responded_by) REFERENCES public.staff_credentials(id);

ALTER TABLE "public"."passengers"
  ADD CONSTRAINT "passengers_approved_by_fkey" FOREIGN KEY (approved_by) REFERENCES public.staff_credentials(id);

ALTER TABLE "public"."seat_reservations"
  ADD CONSTRAINT "seat_reservations_responded_by_fkey" FOREIGN KEY (responded_by) REFERENCES public.staff_credentials(id);

ALTER TABLE "public"."trips"
  ADD CONSTRAINT "trips_bus_id_fkey" FOREIGN KEY (bus_id) REFERENCES public.buses(id);

ALTER TABLE "public"."trips"
  ADD CONSTRAINT "trips_conductor_id_fkey" FOREIGN KEY (conductor_id) REFERENCES public.staff_credentials(id);

ALTER TABLE "public"."trips"
  ADD CONSTRAINT "trips_driver_id_fkey" FOREIGN KEY (driver_id) REFERENCES public.staff_credentials(id);

ALTER TABLE "public"."attendance"
  ADD CONSTRAINT "attendance_trip_id_fkey" FOREIGN KEY (trip_id) REFERENCES public.trips(id) ON DELETE CASCADE;

ALTER TABLE "public"."bus_locations"
  ADD CONSTRAINT "bus_locations_trip_id_fkey" FOREIGN KEY (trip_id) REFERENCES public.trips(id);

CREATE INDEX admin_audit_log_created_at_idx ON public.admin_audit_log USING btree (created_at DESC);

CREATE INDEX admin_audit_log_target_idx ON public.admin_audit_log USING btree (target_table, target_id);

CREATE UNIQUE INDEX chat_rooms_broadcast_unique ON public.chat_rooms USING btree (bus_id)
  WHERE (room_type = 'broadcast'::text);

CREATE UNIQUE INDEX chat_rooms_direct_unique ON public.chat_rooms USING btree (bus_id, passenger_id)
  WHERE (room_type = 'direct'::text);

CREATE INDEX idx_bus_requests_bus ON public.bus_requests USING btree (bus_id);

CREATE INDEX idx_bus_requests_passenger ON public.bus_requests USING btree (passenger_id);

CREATE INDEX idx_bus_requests_status ON public.bus_requests USING btree (status);

CREATE INDEX idx_messages_room_time ON public.messages USING btree (chat_room_id, sent_at DESC);

CREATE UNIQUE INDEX idx_seat_reservations_active_seat ON public.seat_reservations USING btree (bus_id, seat_number)
  WHERE (status = 'approved'::text);

CREATE TRIGGER trg_bus_route_city_match
  BEFORE INSERT OR UPDATE ON public.buses
  FOR EACH ROW
  EXECUTE FUNCTION public.check_route_belongs_to_city();

CREATE POLICY "conductor_manage_attendance" ON "public"."attendance"
  FOR ALL
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM (public.trips t
     JOIN public.staff_credentials sc ON ((sc.bus_id = t.bus_id)))
  WHERE ((t.id = attendance.trip_id) AND (sc.auth_user_id = auth.uid())))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM (public.trips t
     JOIN public.staff_credentials sc ON ((sc.bus_id = t.bus_id)))
  WHERE ((t.id = attendance.trip_id) AND (sc.auth_user_id = auth.uid())))));

CREATE POLICY "passenger_read_own_attendance" ON "public"."attendance"
  FOR SELECT
  TO "authenticated"
  USING ((passenger_id = auth.uid()));

CREATE POLICY "conductor_write_location" ON "public"."bus_locations"
  FOR ALL
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.staff_credentials sc
  WHERE ((sc.auth_user_id = auth.uid()) AND (sc.bus_id = bus_locations.bus_id)))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.staff_credentials sc
  WHERE ((sc.auth_user_id = auth.uid()) AND (sc.bus_id = bus_locations.bus_id)))));

CREATE POLICY "passenger_read_own_bus_location" ON "public"."bus_locations"
  FOR SELECT
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.passengers p
  WHERE ((p.id = auth.uid()) AND (p.bus_id = bus_locations.bus_id) AND (p.approval_status = 'approved'::text)))));

CREATE POLICY "conductors_select_bus_requests" ON "public"."bus_requests"
  FOR SELECT
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.staff_credentials
  WHERE ((staff_credentials.auth_user_id = auth.uid()) AND (staff_credentials.bus_id = bus_requests.bus_id) AND (staff_credentials.role = 'conductor'::text)))));

CREATE POLICY "conductors_select_for_bus" ON "public"."bus_requests"
  FOR SELECT
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.staff_credentials
  WHERE ((staff_credentials.auth_user_id = auth.uid()) AND (staff_credentials.bus_id = bus_requests.bus_id) AND (staff_credentials.role = 'conductor'::text)))));

CREATE POLICY "conductors_update_bus_requests" ON "public"."bus_requests"
  FOR UPDATE
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.staff_credentials
  WHERE ((staff_credentials.auth_user_id = auth.uid()) AND (staff_credentials.bus_id = bus_requests.bus_id) AND (staff_credentials.role = 'conductor'::text)))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.staff_credentials
  WHERE ((staff_credentials.auth_user_id = auth.uid()) AND (staff_credentials.bus_id = bus_requests.bus_id) AND (staff_credentials.role = 'conductor'::text)))));

CREATE POLICY "conductors_update_for_bus" ON "public"."bus_requests"
  FOR UPDATE
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.staff_credentials
  WHERE ((staff_credentials.auth_user_id = auth.uid()) AND (staff_credentials.bus_id = bus_requests.bus_id) AND (staff_credentials.role = 'conductor'::text)))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.staff_credentials
  WHERE ((staff_credentials.auth_user_id = auth.uid()) AND (staff_credentials.bus_id = bus_requests.bus_id) AND (staff_credentials.role = 'conductor'::text)))));

CREATE POLICY "passengers_insert_own_bus_requests" ON "public"."bus_requests"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((auth.uid() = passenger_id));

CREATE POLICY "passengers_insert_own" ON "public"."bus_requests"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((auth.uid() = passenger_id));

CREATE POLICY "passengers_select_own_bus_requests" ON "public"."bus_requests"
  FOR SELECT
  TO "authenticated"
  USING ((auth.uid() = passenger_id));

CREATE POLICY "passengers_select_own" ON "public"."bus_requests"
  FOR SELECT
  TO "authenticated"
  USING ((auth.uid() = passenger_id));

CREATE POLICY "public_read_stops" ON "public"."bus_stops"
  FOR SELECT
  TO "anon", "authenticated"
  USING (true);

CREATE POLICY "public_read_active_buses" ON "public"."buses"
  FOR SELECT
  TO "anon", "authenticated"
  USING ((is_active = true));

CREATE POLICY "users insert own" ON "public"."chat_room_reads"
  FOR INSERT
  TO PUBLIC
  WITH CHECK ((auth.uid() = user_id));

CREATE POLICY "users read own" ON "public"."chat_room_reads"
  FOR SELECT
  TO PUBLIC
  USING ((auth.uid() = user_id));

CREATE POLICY "users update own" ON "public"."chat_room_reads"
  FOR UPDATE
  TO PUBLIC
  USING ((auth.uid() = user_id));

CREATE POLICY "conductors read bus rooms" ON "public"."chat_rooms"
  FOR SELECT
  TO PUBLIC
  USING ((bus_id IN ( SELECT staff_credentials.bus_id
   FROM public.staff_credentials
  WHERE (staff_credentials.auth_user_id = auth.uid()))));

CREATE POLICY "passengers insert direct room" ON "public"."chat_rooms"
  FOR INSERT
  TO PUBLIC
  WITH CHECK (((room_type = 'direct'::text) AND (passenger_id = auth.uid())));

CREATE POLICY "passengers read own rooms" ON "public"."chat_rooms"
  FOR SELECT
  TO PUBLIC
  USING (((room_type = 'broadcast'::text) OR ((room_type = 'direct'::text) AND (passenger_id = auth.uid()))));

CREATE POLICY "bus_members_read_chatroom" ON "public"."chat_rooms"
  FOR SELECT
  TO "authenticated"
  USING (((EXISTS ( SELECT 1
   FROM public.passengers p
  WHERE ((p.id = auth.uid()) AND (p.bus_id = chat_rooms.bus_id) AND (p.approval_status = 'approved'::text)))) OR (EXISTS ( SELECT 1
   FROM public.staff_credentials sc
  WHERE ((sc.auth_user_id = auth.uid()) AND (sc.bus_id = chat_rooms.bus_id))))));

CREATE POLICY "public_read_cities" ON "public"."cities"
  FOR SELECT
  TO "anon", "authenticated"
  USING (true);

CREATE POLICY "passengers manage own pins" ON "public"."custom_pins"
  FOR ALL
  TO PUBLIC
  USING ((passenger_id = auth.uid()))
  WITH CHECK ((passenger_id = auth.uid()));

CREATE POLICY "user_manage_own_reads" ON "public"."message_reads"
  FOR ALL
  TO "authenticated"
  USING ((user_id = auth.uid()))
  WITH CHECK ((user_id = auth.uid()));

CREATE POLICY "bus_members_read_messages" ON "public"."messages"
  FOR SELECT
  TO "authenticated"
  USING (((EXISTS ( SELECT 1
   FROM (public.chat_rooms cr
     JOIN public.passengers p ON ((p.bus_id = cr.bus_id)))
  WHERE ((cr.id = messages.chat_room_id) AND (p.id = auth.uid()) AND (p.approval_status = 'approved'::text)))) OR (EXISTS ( SELECT 1
   FROM (public.chat_rooms cr
     JOIN public.staff_credentials sc ON ((sc.bus_id = cr.bus_id)))
  WHERE ((cr.id = messages.chat_room_id) AND (sc.auth_user_id = auth.uid()))))));

CREATE POLICY "bus_members_send_messages" ON "public"."messages"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((sender_id = auth.uid()) AND ((EXISTS ( SELECT 1
   FROM (public.chat_rooms cr
     JOIN public.passengers p ON ((p.bus_id = cr.bus_id)))
  WHERE ((cr.id = messages.chat_room_id) AND (p.id = auth.uid()) AND (p.approval_status = 'approved'::text)))) OR (EXISTS ( SELECT 1
   FROM (public.chat_rooms cr
     JOIN public.staff_credentials sc ON ((sc.bus_id = cr.bus_id)))
  WHERE ((cr.id = messages.chat_room_id) AND (sc.auth_user_id = auth.uid())))))));

CREATE POLICY "conductor_read_bus_passengers" ON "public"."passengers"
  FOR SELECT
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.staff_credentials sc
  WHERE ((sc.auth_user_id = auth.uid()) AND (sc.bus_id = passengers.bus_id) AND (sc.role = 'conductor'::text)))));

CREATE POLICY "conductor_read_pending_passengers" ON "public"."passengers"
  FOR SELECT
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.bus_requests br
  WHERE ((br.passenger_id = passengers.id) AND ((br.status)::text = 'pending'::text) AND (EXISTS ( SELECT 1
           FROM public.staff_credentials sc
          WHERE ((sc.auth_user_id = auth.uid()) AND (sc.bus_id = br.bus_id) AND (sc.role = 'conductor'::text))))))));

CREATE POLICY "conductor_update_approval" ON "public"."passengers"
  FOR UPDATE
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.staff_credentials sc
  WHERE ((sc.auth_user_id = auth.uid()) AND (sc.bus_id = passengers.bus_id) AND (sc.role = 'conductor'::text)))));

CREATE POLICY "passenger_insert_own" ON "public"."passengers"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((auth.uid() = id));

CREATE POLICY "passenger_read_own" ON "public"."passengers"
  FOR SELECT
  TO "authenticated"
  USING ((auth.uid() = id));

CREATE POLICY "passenger_update_own" ON "public"."passengers"
  FOR UPDATE
  TO PUBLIC
  USING ((auth.uid() = id))
  WITH CHECK ((auth.uid() = id));

CREATE POLICY "public_read_routes" ON "public"."routes"
  FOR SELECT
  TO "anon", "authenticated"
  USING (true);

CREATE POLICY "bus_members_read_bookings" ON "public"."seat_bookings"
  FOR SELECT
  TO "authenticated"
  USING (((EXISTS ( SELECT 1
   FROM public.passengers p
  WHERE ((p.id = auth.uid()) AND (p.bus_id = seat_bookings.bus_id) AND (p.approval_status = 'approved'::text)))) OR (EXISTS ( SELECT 1
   FROM public.staff_credentials sc
  WHERE ((sc.auth_user_id = auth.uid()) AND (sc.bus_id = seat_bookings.bus_id))))));

CREATE POLICY "passenger_book_own_seat" ON "public"."seat_bookings"
  FOR INSERT
  TO "authenticated"
  WITH
    CHECK (((passenger_id = auth.uid()) AND (booking_date = CURRENT_DATE) AND (EXTRACT(hour FROM (now() AT TIME ZONE 'Asia/Kolkata'::text)) < (20)::numeric) AND (EXISTS ( SELECT 1
   FROM public.passengers p
  WHERE ((p.id = auth.uid()) AND (p.bus_id = seat_bookings.bus_id) AND (p.approval_status = 'approved'::text))))));

CREATE POLICY "passenger_cancel_own_booking" ON "public"."seat_bookings"
  FOR DELETE
  TO "authenticated"
  USING (((passenger_id = auth.uid()) AND (booking_date = CURRENT_DATE) AND (EXTRACT(hour FROM (now() AT TIME ZONE 'Asia/Kolkata'::text)) < (20)::numeric)));

CREATE POLICY "staff_read_own" ON "public"."staff_credentials"
  FOR SELECT
  TO "authenticated"
  USING ((auth_user_id = auth.uid()));

CREATE POLICY "conductor_manage_own_trip" ON "public"."trips"
  FOR ALL
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.staff_credentials sc
  WHERE ((sc.auth_user_id = auth.uid()) AND (sc.bus_id = trips.bus_id)))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.staff_credentials sc
  WHERE ((sc.auth_user_id = auth.uid()) AND (sc.bus_id = trips.bus_id)))));

CREATE POLICY "passenger_read_own_trip" ON "public"."trips"
  FOR SELECT
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.passengers p
  WHERE ((p.id = auth.uid()) AND (p.bus_id = trips.bus_id) AND (p.approval_status = 'approved'::text)))));

CREATE EVENT TRIGGER "ensure_rls"
  ON ddl_command_end
  WHEN TAG IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
  EXECUTE FUNCTION "public"."rls_auto_enable"();

ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."attendance";

ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."bus_locations";

ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."messages";

ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."passengers";

ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."seat_bookings";

ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."trips";

COMMENT ON EXTENSION "pg_cron" IS 'Job scheduler for PostgreSQL';

COMMENT ON EXTENSION "unaccent" IS 'text search dictionary that removes accents';

GRANT EXECUTE ON FUNCTION "public"."approve_bus_request"(uuid, uuid) TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."approve_seat_reservation"(uuid, uuid) TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."book_seat"(uuid, uuid, integer, date) TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."check_route_belongs_to_city"() TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."demo_advance_bus"() TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."detect_user_type"(text) TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."finalize_trip_attendance"(uuid) TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."initialize_trip_attendance"(uuid) TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."reject_bus_request"(uuid, uuid, text) TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."reject_seat_reservation"(uuid, uuid, text) TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."remove_passenger"(uuid) TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."remove_seat_reservation"(uuid) TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."rls_auto_enable"() TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."save_translation"(uuid, text, text) TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."update_faculty_rows"(uuid, integer, integer) TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."admin_audit_log" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."attendance" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."bus_locations" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."bus_requests" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."bus_stops" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."buses" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."chat_room_reads" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."chat_rooms" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."cities" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."custom_pins" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."message_reads" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."messages" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."passengers" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."routes" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."seat_bookings" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."seat_reservations" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."staff_credentials" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."trips" TO "anon", "authenticated", "postgres", "service_role";

SELECT cron.schedule_in_database('cleanup-old-seat-bookings', '30 14 * * *', '
    delete from public.seat_bookings
    where booking_date < current_date - interval ''7 days'';
  ', 'postgres', NULL, true);

SELECT cron.schedule_in_database('reset-seat-bookings', '30 14 * * *', 'DELETE FROM public.seat_bookings WHERE booking_date < CURRENT_DATE;', 'postgres', NULL, true);

SELECT cron.schedule_in_database('vbus_demo_mover', '* * * * *', 'select demo_advance_bus();', 'postgres', NULL, true);

ALTER TABLE "public"."passengers"
  ADD CONSTRAINT "user_type_matches_email" CHECK ((user_type = public.detect_user_type(email)));

