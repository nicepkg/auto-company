-- Cycle 005 Evidence Queries (Supabase Dashboard -> SQL Editor)
-- Date: 2026-02-13
--
-- Purpose:
-- - After running a hosted workflow with a known run_id, use these queries to
--   prove persistence in `workflow_runs` + `workflow_events`.
--
-- Replace <RUN_ID> with the real run id (example: pilot-001-customer-originated-db-20260213-123456).

-- 1) Verify tables exist
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in ('workflow_app_meta', 'workflow_runs', 'workflow_events', 'pilot_deals')
order by table_name;

-- 1b) Verify schema bundle ID (prevents "wrong schema" evidence)
select meta_key, meta_value, updated_at
from public.workflow_app_meta
where meta_key = 'schema_bundle_id';

-- 2) Fetch the run row
select *
from public.workflow_runs
where run_id = '<RUN_ID>';

-- 3) Fetch all events for the run (chronological)
select run_id, step, status, created_at, payload
from public.workflow_events
where run_id = '<RUN_ID>'
order by created_at asc;

-- 4) Quick summary: which steps were recorded, and how many times
select step, status, count(*) as n
from public.workflow_events
where run_id = '<RUN_ID>'
group by step, status
order by step, status;

-- 5) Optional: latest runs (sanity check)
select run_id, status, citation_gate_passed, approval_gate_passed, reviewer, created_at, updated_at
from public.workflow_runs
order by created_at desc
limit 25;
