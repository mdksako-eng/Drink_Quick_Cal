-- ============================================================
-- RLS: drink_recipes (what a MADE drink is made of)
-- ============================================================
-- WHY: this table holds the shop's purchase prices and the quantities it pours —
-- in other words its margins. The anon key shipped inside the app must never be
-- able to read or forge them.
--
-- The app only touches it through the session-authenticated backend
-- (/api/data/recipes …), and the backend connects as the table owner (postgres),
-- which BYPASSES RLS — so enabling RLS with no policies changes nothing for the
-- app while closing the anon hole.
--
-- APPLY:
--   Option A (fastest): Supabase Dashboard -> SQL Editor -> paste -> Run.
--   Option B (CI/ops):  psql "$DATABASE_URL" -f sql/rls_recipes.sql
-- ============================================================

ALTER TABLE public.drink_recipes ENABLE ROW LEVEL SECURITY;

-- Drop any pre-existing policy: a permissive policy would re-open access.
DO $$
DECLARE
  pol record;
BEGIN
  FOR pol IN
    SELECT policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'drink_recipes'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.drink_recipes', pol.policyname);
    RAISE NOTICE 'Dropped policy % on drink_recipes', pol.policyname;
  END LOOP;
END $$;

-- Belt and braces: revoke direct privileges from the client roles as well.
REVOKE ALL ON public.drink_recipes FROM anon, authenticated;

-- ------------------------------------------------------------
-- VERIFY (run after applying)
-- ------------------------------------------------------------
-- SELECT relname, relrowsecurity FROM pg_class WHERE relname = 'drink_recipes';
--   -> must be true
-- SELECT policyname FROM pg_policies WHERE tablename = 'drink_recipes';
--   -> must return no rows
-- With the anon key (must return [] or a permission error):
--   GET {SUPABASE_URL}/rest/v1/drink_recipes?select=id
-- ------------------------------------------------------------
