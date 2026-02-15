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
