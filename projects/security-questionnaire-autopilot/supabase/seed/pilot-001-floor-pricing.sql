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
