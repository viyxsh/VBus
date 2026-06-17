-- ============================================================================
-- VBUS — web-demo seed
--
-- Gives the demo student's bus a live, self-moving trip so the passenger map's
-- stop timeline and "ETA to your stop" animate on their own (no conductor app
-- needed). The passenger app recomputes the ETA on every realtime location
-- update, so a server-side job that nudges `bus_locations` is all it takes.
--
-- HOW TO RUN
--   1. Supabase Dashboard → SQL Editor → paste this whole file → Run.
--      (The SQL editor runs as a privileged role, so RLS does not block it.)
--   2. Set v_email below to your DEMO_STUDENT_EMAIL (appears in TWO places).
--   3. Make sure that demo student is approved and assigned to a bus, and the
--      bus's route has stops with real latitude/longitude.
--
-- Safe to re-run. Teardown commands are at the bottom.
-- ============================================================================


-- ── Part A: start one ongoing trip + an initial live location ───────────────
do $$
declare
  v_email     text := 'demo.23bce10001@vitbhopal.ac.in';  -- <-- set to DEMO_STUDENT_EMAIL
  v_bus       uuid;
  v_route     uuid;
  v_conductor uuid;
  v_trip      uuid;
  v_n         int;
  v_idx       int;
  s_lat numeric; s_lng numeric; n_lat numeric; n_lng numeric;
begin
  select p.bus_id, b.route_id
    into v_bus, v_route
    from passengers p
    join buses b on b.id = p.bus_id
   where lower(p.email) = lower(v_email)
   limit 1;
  if v_bus is null then
    raise exception 'No passenger found with email % (set v_email)', v_email;
  end if;

  -- Make sure the demo student is approved (else the app shows the pending screen).
  update passengers set approval_status = 'approved'
   where lower(email) = lower(v_email);

  -- trips.conductor_id is required → reuse the bus's conductor record.
  select id into v_conductor from staff_credentials where bus_id = v_bus limit 1;
  if v_conductor is null then
    raise exception 'No staff_credentials (conductor) for bus % — create one first', v_bus;
  end if;

  select count(*) into v_n from bus_stops where route_id = v_route;
  if v_n < 2 then
    raise exception 'Route % needs at least 2 stops with coordinates', v_route;
  end if;

  -- Start a third of the way in so there are passed AND upcoming stops.
  v_idx := greatest(0, (v_n / 3)::int);

  -- Keep exactly one ongoing trip for today.
  update trips set state = 'ended', ended_at = now()
   where bus_id = v_bus and trip_date = current_date and state = 'ongoing';

  insert into trips (bus_id, conductor_id, trip_date, state, started_at, current_stop_index)
  values (v_bus, v_conductor, current_date, 'ongoing', now(), v_idx)
  returning id into v_trip;

  -- Drop the bus 30% of the way from stop[v_idx] toward stop[v_idx+1].
  select latitude, longitude into s_lat, s_lng
    from bus_stops where route_id = v_route order by stop_order offset v_idx limit 1;
  select latitude, longitude into n_lat, n_lng
    from bus_stops where route_id = v_route order by stop_order offset (v_idx + 1) limit 1;

  delete from bus_locations where bus_id = v_bus;
  insert into bus_locations (bus_id, trip_id, latitude, longitude, heading, speed_kmh, updated_at)
  values (v_bus, v_trip,
          s_lat + (n_lat - s_lat) * 0.3,
          s_lng + (n_lng - s_lng) * 0.3,
          0, 28, now());

  raise notice 'Demo trip % is live on bus % (starting near stop %)', v_trip, v_bus, v_idx;
end $$;


-- ── Part B: the mover — glides the demo bus along its route, then loops ──────
-- Called once a minute by pg_cron (below). Each call advances the bus ~25% of
-- the remaining gap to the next stop (~a realistic block per minute), advancing
-- the current stop when it arrives, and resets to the first stop at the end so
-- the demo runs forever. Scoped to the demo bus only — real trips are untouched.
create or replace function demo_advance_bus() returns void
language plpgsql
as $$
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
end $$;


-- ── Part C: schedule the mover every minute (pg_cron) ───────────────────────
-- Enable pg_cron once: Dashboard → Database → Extensions → enable "pg_cron",
-- or run the create extension below.
create extension if not exists pg_cron;

-- Remove any previous schedule, then (re)create it.
select cron.unschedule('vbus_demo_mover')
  where exists (select 1 from cron.job where jobname = 'vbus_demo_mover');
select cron.schedule('vbus_demo_mover', '* * * * *', $$select demo_advance_bus();$$);


-- ============================================================================
-- OPTIONAL: smoother motion (updates every ~5s instead of every minute).
-- Replace the schedule above with a tick that sub-steps within each minute.
-- Comment out Part C's cron.schedule and use this instead:
--
--   create or replace function demo_run_tick() returns void language plpgsql as $$
--   declare i int;
--   begin
--     for i in 1..11 loop
--       perform demo_advance_bus();
--       perform pg_sleep(5);
--     end loop;
--   end $$;
--   select cron.schedule('vbus_demo_mover', '* * * * *', $$select demo_run_tick();$$);
-- ============================================================================


-- ============================================================================
-- TEARDOWN (run to stop the demo):
--   select cron.unschedule('vbus_demo_mover');
--   update trips set state = 'ended', ended_at = now()
--     where state = 'ongoing' and trip_date = current_date;
--   drop function if exists demo_advance_bus();
--   -- drop function if exists demo_run_tick();
-- ============================================================================
