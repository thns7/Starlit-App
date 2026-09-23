-- Starlit: schema inicial
-- Perfis, filmes, reviews, curtidas, comentários, amizades, mensagens e avatares.

-- =========================================================
-- Perfis (1:1 com auth.users)
-- =========================================================
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null unique
    check (username ~ '^[a-z0-9_.]{3,30}$'),
  name text not null default '' check (char_length(name) <= 80),
  bio text not null default '' check (char_length(bio) <= 300),
  avatar_url text,
  created_at timestamptz not null default now()
);

-- Cria o perfil automaticamente quando alguém se cadastra.
-- O app manda username/name/avatar_url em options.data do signUp.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, username, name, avatar_url)
  values (
    new.id,
    lower(coalesce(nullif(new.raw_user_meta_data ->> 'username', ''), 'user_' || substr(new.id::text, 1, 8))),
    coalesce(new.raw_user_meta_data ->> 'name', ''),
    nullif(new.raw_user_meta_data ->> 'avatar_url', '')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Permite checar se um username está livre antes do cadastro (inclusive sem login).
create function public.username_available(p_username text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (
    select 1 from public.profiles where username = lower(p_username)
  );
$$;

-- =========================================================
-- Filmes
-- =========================================================
create table public.movies (
  id bigint generated always as identity primary key,
  title text not null check (char_length(title) between 1 and 200),
  year int check (year between 1870 and 2100),
  poster_url text,
  created_by uuid references public.profiles (id) on delete set null default auth.uid(),
  created_at timestamptz not null default now()
);

create unique index movies_title_year_key on public.movies (lower(title), coalesce(year, 0));

-- =========================================================
-- Reviews
-- =========================================================
create table public.reviews (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles (id) on delete cascade default auth.uid(),
  movie_id bigint not null references public.movies (id) on delete cascade,
  content text not null check (char_length(content) between 1 and 5000),
  rating smallint not null check (rating between 1 and 5),
  is_public boolean not null default true,
  created_at timestamptz not null default now()
);

create index reviews_user_id_idx on public.reviews (user_id);
create index reviews_movie_id_idx on public.reviews (movie_id);
create index reviews_created_at_idx on public.reviews (created_at desc);

create table public.review_likes (
  review_id bigint not null references public.reviews (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade default auth.uid(),
  created_at timestamptz not null default now(),
  primary key (review_id, user_id)
);

create index review_likes_user_id_idx on public.review_likes (user_id);

create table public.comments (
  id bigint generated always as identity primary key,
  review_id bigint not null references public.reviews (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade default auth.uid(),
  content text not null check (char_length(content) between 1 and 2000),
  created_at timestamptz not null default now()
);

create index comments_review_id_idx on public.comments (review_id);
create index comments_user_id_idx on public.comments (user_id);

-- =========================================================
-- Amizades
-- =========================================================
create table public.friendships (
  requester_id uuid not null references public.profiles (id) on delete cascade default auth.uid(),
  addressee_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  primary key (requester_id, addressee_id),
  check (requester_id <> addressee_id)
);

-- Impede pedido duplicado na direção oposta (A->B e B->A).
create unique index friendships_pair_key on public.friendships (
  least(requester_id, addressee_id), greatest(requester_id, addressee_id)
);
create index friendships_addressee_id_idx on public.friendships (addressee_id);

create function public.are_friends(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.friendships f
    where f.status = 'accepted'
      and ((f.requester_id = a and f.addressee_id = b)
        or (f.requester_id = b and f.addressee_id = a))
  );
$$;

-- =========================================================
-- Mensagens (chat entre amigos)
-- =========================================================
create table public.messages (
  id bigint generated always as identity primary key,
  sender_id uuid not null references public.profiles (id) on delete cascade default auth.uid(),
  receiver_id uuid not null references public.profiles (id) on delete cascade,
  content text not null check (char_length(content) between 1 and 2000),
  created_at timestamptz not null default now()
);

create index messages_pair_idx on public.messages (sender_id, receiver_id, created_at);
create index messages_receiver_id_idx on public.messages (receiver_id);

alter publication supabase_realtime add table public.messages;

-- =========================================================
-- Row Level Security
-- =========================================================
alter table public.profiles enable row level security;
alter table public.movies enable row level security;
alter table public.reviews enable row level security;
alter table public.review_likes enable row level security;
alter table public.comments enable row level security;
alter table public.friendships enable row level security;
alter table public.messages enable row level security;

-- profiles
create policy "Perfis visíveis para usuários logados" on public.profiles
  for select to authenticated using (true);
create policy "Usuário edita o próprio perfil" on public.profiles
  for update to authenticated
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

-- movies
create policy "Filmes visíveis para usuários logados" on public.movies
  for select to authenticated using (true);
create policy "Usuário logado cadastra filme" on public.movies
  for insert to authenticated with check ((select auth.uid()) = created_by);

-- reviews: públicas, próprias ou de amigos
create policy "Ver reviews públicas, próprias ou de amigos" on public.reviews
  for select to authenticated using (
    is_public
    or user_id = (select auth.uid())
    or public.are_friends(user_id, (select auth.uid()))
  );
create policy "Criar a própria review" on public.reviews
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Editar a própria review" on public.reviews
  for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Apagar a própria review" on public.reviews
  for delete to authenticated using ((select auth.uid()) = user_id);

-- review_likes
create policy "Curtidas visíveis para usuários logados" on public.review_likes
  for select to authenticated using (true);
create policy "Curtir como si mesmo" on public.review_likes
  for insert to authenticated with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.reviews r where r.id = review_id)
  );
create policy "Descurtir a própria curtida" on public.review_likes
  for delete to authenticated using ((select auth.uid()) = user_id);

-- comments (a subconsulta em reviews respeita o RLS de reviews)
create policy "Ver comentários de reviews visíveis" on public.comments
  for select to authenticated using (
    exists (select 1 from public.reviews r where r.id = review_id)
  );
create policy "Comentar como si mesmo" on public.comments
  for insert to authenticated with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.reviews r where r.id = review_id)
  );
create policy "Apagar o próprio comentário" on public.comments
  for delete to authenticated using ((select auth.uid()) = user_id);

-- friendships
create policy "Ver amizades das quais participo" on public.friendships
  for select to authenticated using (
    (select auth.uid()) in (requester_id, addressee_id)
  );
create policy "Enviar pedido de amizade" on public.friendships
  for insert to authenticated with check (
    (select auth.uid()) = requester_id and status = 'pending'
  );
create policy "Aceitar pedido recebido" on public.friendships
  for update to authenticated
  using ((select auth.uid()) = addressee_id)
  with check ((select auth.uid()) = addressee_id and status = 'accepted');
create policy "Desfazer amizade ou pedido" on public.friendships
  for delete to authenticated using (
    (select auth.uid()) in (requester_id, addressee_id)
  );

-- messages
create policy "Ver as próprias conversas" on public.messages
  for select to authenticated using (
    (select auth.uid()) in (sender_id, receiver_id)
  );
create policy "Enviar mensagem para amigo" on public.messages
  for insert to authenticated with check (
    (select auth.uid()) = sender_id
    and public.are_friends(sender_id, receiver_id)
  );

-- Funções auxiliares não devem ser chamadas por qualquer um além do necessário.
revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.are_friends(uuid, uuid) from public, anon;
grant execute on function public.are_friends(uuid, uuid) to authenticated;
grant execute on function public.username_available(text) to anon, authenticated;

-- =========================================================
-- Storage: avatares (bucket público, cada usuário escreve só na própria pasta)
-- =========================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 5242880, array['image/jpeg', 'image/png', 'image/webp', 'image/gif'])
on conflict (id) do nothing;

create policy "Usuário envia o próprio avatar" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text
  );
create policy "Usuário atualiza o próprio avatar" on storage.objects
  for update to authenticated using (
    bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text
  );
create policy "Usuário apaga o próprio avatar" on storage.objects
  for delete to authenticated using (
    bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- =========================================================
-- Catálogo inicial de filmes
-- =========================================================
insert into public.movies (title, year, created_by) values
  ('Interestelar', 2014, null),
  ('O Poderoso Chefão', 1972, null),
  ('Parasita', 2019, null),
  ('A Viagem de Chihiro', 2001, null),
  ('Cidade de Deus', 2002, null),
  ('Oppenheimer', 2023, null),
  ('Duna: Parte Dois', 2024, null),
  ('Tudo em Todo o Lugar ao Mesmo Tempo', 2022, null),
  ('Homem-Aranha: Através do Aranhaverso', 2023, null),
  ('Ainda Estou Aqui', 2024, null);
