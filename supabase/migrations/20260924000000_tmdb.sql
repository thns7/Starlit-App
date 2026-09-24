-- Integração com o TMDB (The Movie Database).
-- Os filmes vêm do TMDB; quando alguém escreve uma review, o filme é
-- gravado (ou atualizado) na tabela movies, identificado por tmdb_id.

alter table public.movies
  add column tmdb_id int unique,
  add column overview text,
  add column release_date date,
  add column backdrop_url text;

-- Garante que o filme do TMDB existe em movies e devolve o id local.
create function public.ensure_tmdb_movie(
  p_tmdb_id int,
  p_title text,
  p_release_date date default null,
  p_poster_url text default null,
  p_backdrop_url text default null,
  p_overview text default null
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id bigint;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  insert into public.movies (tmdb_id, title, year, release_date, poster_url, backdrop_url, overview, created_by)
  values (
    p_tmdb_id,
    left(p_title, 200),
    extract(year from p_release_date)::int,
    p_release_date,
    p_poster_url,
    p_backdrop_url,
    p_overview,
    auth.uid()
  )
  on conflict (tmdb_id) do update set
    title = excluded.title,
    year = excluded.year,
    release_date = excluded.release_date,
    poster_url = excluded.poster_url,
    backdrop_url = excluded.backdrop_url,
    overview = excluded.overview
  returning id into v_id;

  return v_id;
end;
$$;

revoke execute on function public.ensure_tmdb_movie(int, text, date, text, text, text) from public, anon;
grant execute on function public.ensure_tmdb_movie(int, text, date, text, text, text) to authenticated;

-- O índice único (título, ano) impediria dois filmes homônimos do mesmo ano
-- vindos do TMDB; a unicidade passa a valer só para filmes cadastrados à mão.
drop index public.movies_title_year_key;
create unique index movies_title_year_key on public.movies (lower(title), coalesce(year, 0))
  where tmdb_id is null;
