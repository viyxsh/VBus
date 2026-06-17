-- ============================================================================
-- VBUS — create the demo PASSENGER row for the web demo's dummy login.
--
-- PREREQUISITE: first create the Auth user in the Dashboard
--   Authentication → Users → Add user → email + password → Auto Confirm.
--   (The dummy login uses email/password; Google accounts have no password.)
--
-- Then set v_email below to that user's email and run this in the SQL Editor.
-- Idempotent: re-running just re-points/approves the demo passenger.
-- ============================================================================
do $$
declare
  v_email text := 'demo.23bce10001@vitbhopal.ac.in';  -- <-- the Auth user you created
  v_uid   uuid;
  v_bus   uuid;
  v_city  uuid;
  v_route uuid;
  v_stop  uuid;
  v_n     int;
begin
  select id into v_uid from auth.users where lower(email) = lower(v_email) limit 1;
  if v_uid is null then
    raise exception
      'Create the Auth user % first (Dashboard → Authentication → Add user, Auto Confirm + password)',
      v_email;
  end if;

  -- Pick a bus that has a conductor and a route with at least 2 stops.
  select b.id, b.city_id, b.route_id
    into v_bus, v_city, v_route
    from buses b
   where exists (select 1 from staff_credentials s where s.bus_id = b.id)
     and (select count(*) from bus_stops bs where bs.route_id = b.route_id) >= 2
   order by b.bus_number
   limit 1;
  if v_bus is null then
    raise exception 'No suitable bus found (needs a conductor + a route with >= 2 stops)';
  end if;

  -- Board the demo student ~2/3 along the route so an approaching bus shows a
  -- counting-down ETA (the demo trip starts ~1/3 along).
  select count(*) into v_n from bus_stops where route_id = v_route;
  select id into v_stop
    from bus_stops where route_id = v_route
   order by stop_order offset least((2 * v_n) / 3, v_n - 1) limit 1;

  -- user_type is locked by a CHECK (user_type = detect_user_type(email)): the
  -- function returns 'student' only for the real pattern firstname.YYBBBnnnnn
  -- @vitbhopal.ac.in (e.g. viya.23bce11351@vitbhopal.ac.in), else 'faculty'.
  -- Use a student-pattern email so the demo gets the student app.
  insert into passengers
    (id, name, institute_id, email, user_type, city_id, bus_id, stop_id, approval_status)
  values
    (v_uid, 'Demo Student', 'DEMO001', v_email, detect_user_type(v_email),
     v_city, v_bus, v_stop, 'approved')
  on conflict (id) do update
    set bus_id          = excluded.bus_id,
        stop_id         = excluded.stop_id,
        city_id         = excluded.city_id,
        approval_status = 'approved';

  raise notice 'Demo passenger ready on bus % (boarding stop set ~2/3 along)', v_bus;
end $$;
