alter table public.properties
  add column if not exists moderation_status text not null default 'pending',
  add column if not exists moderation_note text,
  add column if not exists moderated_by uuid
    references public.profiles(id) on delete set null,
  add column if not exists moderated_at timestamptz;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'properties_moderation_status_check'
  ) then
    alter table public.properties
      add constraint properties_moderation_status_check
      check (
        moderation_status in (
          'pending',
          'approved',
          'changes_requested',
          'rejected'
        )
      );
  end if;
end
$$;

create index if not exists properties_moderation_status_idx
  on public.properties (moderation_status);

alter table public.notifications
  add column if not exists related_property_id uuid
    references public.properties(id) on delete set null,
  add column if not exists related_conversation_id uuid,
  add column if not exists is_read boolean not null default false;

create table if not exists public.moderation_audit_log (
  id uuid primary key default gen_random_uuid(),
  case_type text not null check (case_type in ('submission', 'report')),
  case_id uuid not null,
  property_id uuid references public.properties(id) on delete set null,
  admin_id uuid not null references public.profiles(id) on delete restrict,
  decision text not null
    check (decision in ('approve', 'request_changes', 'reject')),
  reason text not null check (length(trim(reason)) > 0),
  previous_status text not null,
  new_status text not null,
  created_at timestamptz not null default now()
);

create index if not exists moderation_audit_log_property_idx
  on public.moderation_audit_log (property_id, created_at desc);
create index if not exists moderation_audit_log_case_idx
  on public.moderation_audit_log (case_type, case_id, created_at desc);

alter table public.moderation_audit_log enable row level security;

drop policy if exists "admins_view_moderation_audit_log"
  on public.moderation_audit_log;
create policy "admins_view_moderation_audit_log"
  on public.moderation_audit_log
  for select
  using (
    exists (
      select 1
      from public.profiles
      where id = auth.uid()
        and role = 'admin'
    )
  );

grant select on public.moderation_audit_log to authenticated;

create or replace function public.resolve_moderation_case(
  p_case_type text,
  p_case_id uuid,
  p_decision text,
  p_reason text
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_admin_id uuid := auth.uid();
  v_property public.properties%rowtype;
  v_report public.moderation_reports%rowtype;
  v_previous_status text;
  v_new_status text;
  v_case_title text;
  v_agent_id uuid;
  v_reporter_id uuid;
  v_audit_id uuid;
begin
  if v_admin_id is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1
    from public.profiles
    where id = v_admin_id
      and role = 'admin'
  ) then
    raise exception 'Administrator access required';
  end if;

  if p_reason is null or length(trim(p_reason)) = 0 then
    raise exception 'A decision reason is required';
  end if;

  if p_case_type not in ('submission', 'report') then
    raise exception 'Unknown moderation case type: %', p_case_type;
  end if;

  if p_decision not in ('approve', 'request_changes', 'reject') then
    raise exception 'Unknown moderation decision: %', p_decision;
  end if;

  if p_case_type = 'submission' then
    select *
      into v_property
      from public.properties
      where id = p_case_id
        and moderation_status = 'pending'
      for update;

    if not found then
      raise exception 'Submission case is no longer pending';
    end if;

    v_previous_status := v_property.status;
    v_case_title := v_property.title;
    v_agent_id := v_property.agent_id;
    v_new_status := case p_decision
      when 'approve' then 'active'
      when 'request_changes' then 'pending'
      else 'archived'
    end;

    update public.properties
      set
        status = v_new_status,
        moderation_status = case p_decision
          when 'approve' then 'approved'
          when 'request_changes' then 'changes_requested'
          else 'rejected'
        end,
        moderation_note = trim(p_reason),
        moderated_by = v_admin_id,
        moderated_at = now()
      where id = p_case_id;
  else
    if p_decision = 'request_changes' then
      raise exception 'Report cases cannot request changes';
    end if;

    select *
      into v_report
      from public.moderation_reports
      where id = p_case_id
        and status in ('pending', 'reviewing')
      for update;

    if not found then
      raise exception 'Report case is no longer pending';
    end if;

    v_previous_status := v_report.status;
    v_reporter_id := v_report.reporter_id;
    v_agent_id := v_report.reported_user_id;
    v_new_status := case p_decision
      when 'approve' then 'resolved'
      else 'dismissed'
    end;

    if v_report.reported_property_id is not null then
      select *
        into v_property
        from public.properties
        where id = v_report.reported_property_id
        for update;

      v_case_title := coalesce(v_property.title, 'Reported listing');
      if p_decision = 'approve' then
        update public.properties
          set
            status = 'archived',
            moderation_status = 'rejected',
            moderation_note = trim(p_reason),
            moderated_by = v_admin_id,
            moderated_at = now()
          where id = v_report.reported_property_id;
      end if;
    else
      v_case_title := 'Moderation report';
    end if;

    update public.moderation_reports
      set
        status = v_new_status,
        resolved_by = v_admin_id,
        resolution_note = trim(p_reason),
        resolved_at = now()
      where id = p_case_id;
  end if;

  insert into public.moderation_audit_log (
    case_type,
    case_id,
    property_id,
    admin_id,
    decision,
    reason,
    previous_status,
    new_status
  )
  values (
    p_case_type,
    p_case_id,
    case
      when p_case_type = 'submission' then v_property.id
      else v_report.reported_property_id
    end,
    v_admin_id,
    p_decision,
    trim(p_reason),
    v_previous_status,
    v_new_status
  )
  returning id into v_audit_id;

  if v_agent_id is not null then
    insert into public.notifications (
      user_id,
      title,
      message,
      type,
      related_property_id,
      is_read
    )
    values (
      v_agent_id,
      case
        when p_decision = 'approve' and p_case_type = 'submission'
          then 'Listing approved'
        when p_decision = 'request_changes'
          then 'Listing changes requested'
        else 'Listing moderation update'
      end,
      coalesce(v_case_title, 'Your listing') || ': ' ||
        case
          when p_decision = 'approve' and p_case_type = 'submission'
            then 'published after review.'
          when p_decision = 'request_changes'
            then trim(p_reason)
          else trim(p_reason)
        end,
      'moderation_result',
      case
        when p_case_type = 'submission' then v_property.id
        else v_report.reported_property_id
      end,
      false
    );
  end if;

  if p_case_type = 'report' and v_reporter_id is not null then
    insert into public.notifications (
      user_id,
      title,
      message,
      type,
      related_property_id,
      is_read
    )
    values (
      v_reporter_id,
      'Listing report reviewed',
      case p_decision
        when 'approve' then 'Your report was confirmed and the listing was hidden.'
        else 'Your report was reviewed and dismissed.'
      end,
      'moderation_result',
      v_report.reported_property_id,
      false
    );
  end if;

  return v_audit_id;
end;
$$;

revoke all on function public.resolve_moderation_case(
  text, uuid, text, text
) from public, anon;
grant execute on function public.resolve_moderation_case(
  text, uuid, text, text
) to authenticated;

comment on function public.resolve_moderation_case(
  text, uuid, text, text
) is
  'Atomically resolves an admin moderation case, updates the target, writes '
  'an immutable audit record, and notifies the agent/reporting user.';