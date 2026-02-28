-- ============================================================================
-- VBUS — set up the demo CONDUCTOR for the web demo's dummy login.
--
-- Conductors sign in with a username that maps to a synthetic Auth email:
--   username "conductor_demo"  ->  conductor_demo@vbus.internal
-- The app then finds the staff_credentials row by auth_user_id.
--
-- PREREQUISITE: create the Auth user in the Dashboard FIRST
--   Authentication → Users → Add user
--     Email:    conductor_demo@vbus.internal
--     Password: (your choice — goes in .env.json as DEMO_CONDUCTOR_PASSWORD)
--     Auto Confirm ✓
--
-- This repoints the demo student's bus conductor row to that Auth user, so the
-- demo conductor drives the same bus the demo student rides. Idempotent.
-- ============================================================================
do $$
declare
  v_email    text := 'conductor_demo@vbus.internal';  -- the Auth user you created
  v_username text := 'conductor_demo';                 -- DEMO_CONDUCTOR_USERNAME
  v_uid      uuid;
  v_bus      uuid;
  v_cred     uuid;
begin
  -- 1. The demo conductor's Auth user must exist.
  select id into v_uid from auth.users where lower(email) = lower(v_email) limit 1;
  if v_uid is null then
    raise exception
      'Create the Auth user % first (Dashboard → Authentication → Add user, Auto Confirm + password)',
      v_email;
  end if;

  -- 2. The bus the demo student is assigned to (so both apps share one trip).
  select bus_id into v_bus
    from passengers
   where lower(email) = lower('demo.23bce10001@vitbhopal.ac.in')
   limit 1;
  if v_bus is null then
    raise exception 'Demo student/passenger not found — run demo_account.sql first';
  end if;

  -- 3. Repoint that bus's existing conductor row to the demo Auth user.
  select id into v_cred from staff_credentials where bus_id = v_bus limit 1;
  if v_cred is null then
    raise exception 'No staff_credentials row for bus % to repoint', v_bus;
  end if;

  update staff_credentials
     set auth_user_id = v_uid,
         username     = v_username,
         display_name = 'Demo Conductor'
   where id = v_cred;

  raise notice 'Demo conductor ready: username % drives bus %', v_username, v_bus;
end $$;

-- ============================================================================
-- TEARDOWN (optional): just delete the Auth user in the Dashboard. The staff
-- row keeps working for whatever username/auth_user_id you set it back to.
-- ============================================================================
