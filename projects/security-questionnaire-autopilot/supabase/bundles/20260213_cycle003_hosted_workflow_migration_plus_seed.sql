-- Hosted Workflow: Migration + Seed (Paste-Ready Bundle)
--
-- Purpose:
-- - Paste this entire file into Supabase Dashboard -> SQL Editor and run once.
-- - Keeps migration + seed apply as a single, low-error operation.
--
-- Source files:
-- - supabase/migrations/20260213_cycle003_hosted_workflow.sql
-- - supabase/seed/pilot-001-floor-pricing.sql
--
-- Build: node scripts/build-dashboard-sql-bundle.mjs --migration ... --seed ... --out ...
-- Source SHA256 (migration): 6acacbf2785cd4bfccb80a2e42493ada472e1e52fcf0b9a81341c89efd5c9bb2
-- Source SHA256 (seed): 76305165e91a48f807b6916effb4b686f1b4a77ada17e16901ae8383918bbfdf

-- === MIGRATION ===
create extension if not exists pgcrypto;

-- Minimal schema identity table so hosted health checks can detect
-- "tables exist but wrong version" mismatches deterministically.
create table if not exists public.workflow_app_meta (
  meta_key text primary key,
  meta_value text not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.workflow_runs (
  run_id text primary key,
  status text not null check (status in ('ingested', 'drafted', 'approved', 'exported', 'failed')),
  citation_gate_passed boolean,
  approval_gate_passed boolean,
  reviewer text,
  export_bundle_path text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.workflow_events (
  id uuid primary key default gen_random_uuid(),
  run_id text not null references public.workflow_runs(run_id) on delete cascade,
  step text not null,
  status text not null check (status in ('success', 'failed')),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.pilot_deals (
  id uuid primary key default gen_random_uuid(),
  run_id text references public.workflow_runs(run_id) on delete set null,
  onboarding_fee numeric(10,2) not null,
  monthly_fee numeric(10,2) not null,
  included_questionnaires integer not null,
  overage_fee numeric(10,2) not null,
  expected_questionnaires integer not null,
  estimated_cogs_per_questionnaire numeric(10,2) not null,
  projected_gross_margin numeric(6,4) not null,
  approved boolean not null,
  issues jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  check (onboarding_fee >= 2000),
  check (monthly_fee >= 1800),
  check (included_questionnaires <= 12),
  check (overage_fee >= 150)
);

create index if not exists workflow_events_run_id_created_at_idx
  on public.workflow_events (run_id, created_at desc);

create index if not exists workflow_runs_status_idx
  on public.workflow_runs (status);

-- === SEED ===
insert into public.workflow_runs (
  run_id,
  status,
  citation_gate_passed,
  approval_gate_passed,
  reviewer,
  export_bundle_path,
  metadata
)
values (
  'pilot-001-live-2026-02-13',
  'exported',
  true,
  true,
  'Pilot One Reviewer',
  '/tmp/pilot-001-live-2026-02-13-export.zip',
  '{"seed":"cycle-003","source":"local-run-artifacts"}'::jsonb
)
on conflict (run_id) do update
set
  status = excluded.status,
  citation_gate_passed = excluded.citation_gate_passed,
  approval_gate_passed = excluded.approval_gate_passed,
  reviewer = excluded.reviewer,
  export_bundle_path = excluded.export_bundle_path,
  metadata = excluded.metadata,
  updated_at = now();

-- Schema identity (used by hosted /api/workflow/supabase-health to prevent
-- "evidence captured against the wrong DB schema" failures).
insert into public.workflow_app_meta (meta_key, meta_value, updated_at)
values
  ('schema_bundle_id', '20260213_cycle003_hosted_workflow', now()),
  ('seed_id', 'pilot-001-floor-pricing', now())
on conflict (meta_key) do update
set meta_value = excluded.meta_value,
    updated_at = now();

-- === VERIFY (OPTIONAL; SAFE TO RUN) ===
-- Confirm tables exist.
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in ('workflow_app_meta', 'workflow_runs', 'workflow_events', 'pilot_deals')
order by table_name;

-- Confirm schema bundle id exists.
select meta_key, meta_value, updated_at
from public.workflow_app_meta
where meta_key = 'schema_bundle_id';

-- Confirm seed row exists.
select run_id, status, citation_gate_passed, approval_gate_passed, reviewer, created_at, updated_at
from public.workflow_runs
where run_id = 'pilot-001-live-2026-02-13';
