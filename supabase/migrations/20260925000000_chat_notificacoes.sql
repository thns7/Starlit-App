-- Chat com amigos e avisos em tempo real.

-- =========================================================
-- Mensagens: leitura ("visto")
-- =========================================================
alter table public.messages add column read_at timestamptz;

create index messages_unread_idx on public.messages (receiver_id) where read_at is null;

-- Quem recebeu pode marcar como lida — e só a coluna read_at.
create policy "Marcar como lida mensagem recebida" on public.messages
  for update to authenticated
  using ((select auth.uid()) = receiver_id)
  with check ((select auth.uid()) = receiver_id);

revoke update on public.messages from anon, authenticated;
grant update (read_at) on public.messages to authenticated;

-- Marca como lidas todas as mensagens recebidas de um amigo.
create function public.mark_conversation_read(p_friend uuid)
returns void
language sql
security invoker
set search_path = ''
as $$
  update public.messages
     set read_at = now()
   where receiver_id = auth.uid()
     and sender_id = p_friend
     and read_at is null;
$$;

-- =========================================================
-- Lista de conversas: todos os amigos, com a última mensagem e não lidas.
-- =========================================================
create function public.list_conversations()
returns table (
  friend_id uuid,
  username text,
  name text,
  avatar_url text,
  last_content text,
  last_at timestamptz,
  last_sender uuid,
  last_read_at timestamptz,
  unread bigint
)
language sql
stable
security invoker
set search_path = ''
as $$
  with me as (select auth.uid() as id),
  friends as (
    select case when f.requester_id = me.id then f.addressee_id else f.requester_id end as fid
      from public.friendships f, me
     where f.status = 'accepted'
       and me.id in (f.requester_id, f.addressee_id)
  )
  select p.id, p.username, p.name, p.avatar_url,
         last.content, last.created_at, last.sender_id, last.read_at,
         (select count(*) from public.messages m, me
           where m.sender_id = p.id and m.receiver_id = me.id and m.read_at is null)
    from friends
    join public.profiles p on p.id = friends.fid
    left join lateral (
      select m.content, m.created_at, m.sender_id, m.read_at
        from public.messages m, me
       where (m.sender_id = me.id and m.receiver_id = p.id)
          or (m.sender_id = p.id and m.receiver_id = me.id)
       order by m.created_at desc, m.id desc
       limit 1
    ) last on true
   order by last.created_at desc nulls last, p.username;
$$;

revoke execute on function public.list_conversations() from public, anon;
revoke execute on function public.mark_conversation_read(uuid) from public, anon;
grant execute on function public.list_conversations() to authenticated;
grant execute on function public.mark_conversation_read(uuid) to authenticated;

-- =========================================================
-- Tempo real: pedidos de amizade chegam na hora
-- =========================================================
alter publication supabase_realtime add table public.friendships;
