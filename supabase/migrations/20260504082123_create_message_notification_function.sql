create or replace function public.create_message_notification(
  p_conversation_id uuid,
  p_message_preview text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sender_id uuid := auth.uid();
  v_buyer_id uuid;
  v_agent_id uuid;
  v_property_id uuid;
  v_subject text;
  v_recipient_id uuid;
  v_sender_name text;
  v_preview text;
begin
  if v_sender_id is null then
    raise exception 'Not authenticated';
  end if;

  select buyer_id, agent_id, property_id, subject
  into v_buyer_id, v_agent_id, v_property_id, v_subject
  from public.conversations
  where id = p_conversation_id;

  if v_buyer_id is null or v_agent_id is null then
    raise exception 'Conversation not found';
  end if;

  if v_sender_id = v_buyer_id then
    v_recipient_id := v_agent_id;
  elsif v_sender_id = v_agent_id then
    v_recipient_id := v_buyer_id;
  else
    raise exception 'User is not part of this conversation';
  end if;

  select coalesce(nullif(full_name, ''), email, 'Someone')
  into v_sender_name
  from public.profiles
  where id = v_sender_id;

  v_preview := coalesce(nullif(trim(p_message_preview), ''), 'Sent a message.');

  insert into public.notifications (
    user_id,
    title,
    message,
    type,
    related_property_id,
    related_conversation_id,
    is_read
  )
  values (
    v_recipient_id,
    case
      when coalesce(nullif(trim(v_subject), ''), '') <> ''
        then 'New message about ' || v_subject
      else 'New inquiry reply'
    end,
    coalesce(v_sender_name, 'Someone') || ': ' || v_preview,
    'inquiry_reply',
    v_property_id,
    p_conversation_id,
    false
  );
end;
$$;

grant execute on function public.create_message_notification(uuid, text)
to authenticated;