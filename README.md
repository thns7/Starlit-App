# Starlit App
![Badge em Desenvolvimento](http://img.shields.io/static/v1?label=STATUS&message=EM%20DESENVOLVIMENTO&color=GREEN&style=for-the-badge)


<div align="center">
  <img src="https://github.com/user-attachments/assets/0e11f3c4-8eac-4442-a202-4094600ca4c2" />
</div>


## Descrição
 Versão app da Rede Social Starlit, desenvolvida como parte do Trabalho de Conclusão de Curso dos cursandos de Desenvolvimento de Sistemas no SENAI Nadir Dias de Figueiredo.

## Funcionalidades

- Cadastro, login, sessão persistente e recuperação de senha (Supabase Auth)
- Perfil com foto (upload para o Supabase Storage), nome, @username e descrição
- Reviews de filmes com nota de 1 a 5, públicas ou só para amigos
- Curtidas e comentários nas reviews
- Filmes reais do TMDB: em cartaz, próximos lançamentos, em alta, busca e página de detalhes
- Busca de reviews por filme
- Amizades com pedido/aceite e busca de usuários
- Chat com amigos: lista de conversas, não lidas, "visto", "digitando…" (Supabase Realtime)
- Avisos em tempo real de pedidos de amizade, aceites e mensagens

## Backend (Supabase)

Todo o backend está em [`supabase/migrations`](supabase/migrations): tabelas, regras de
segurança (Row Level Security), bucket de avatares e um catálogo inicial de filmes.

1. Crie um projeto em [supabase.com](https://supabase.com).
2. No painel, abra **SQL Editor**, cole o conteúdo de
   `supabase/migrations/20260923000000_init.sql` e execute
   (ou use a CLI: `supabase link` + `supabase db push`).
3. Em **Authentication → Sign In / Providers → Email**, decida se quer exigir confirmação de
   email. Com ela ligada, o usuário precisa clicar no link do email antes do primeiro login.
4. Execute também, em ordem, `supabase/migrations/20260924000000_tmdb.sql` (TMDB) e
   `supabase/migrations/20260925000000_chat_notificacoes.sql` (chat e avisos em tempo real).
5. Em **Project Settings → API**, copie a *Project URL* e a chave *publishable* (ou *anon*).

## Filmes (TMDB)

Os filmes vêm do [TMDB](https://www.themoviedb.org). Crie uma conta, vá em
**Configurações → API**, solicite uma chave (uso pessoal/educacional) e copie o
**API Read Access Token**. Coloque-o em `TMDB_TOKEN`. Sem o token, o app usa só o
catálogo local da tabela `movies`.

## Rodando o app

```bash
cp env.example.json env.json   # preencha com a URL e a chave do seu projeto
flutter pub get
flutter run --dart-define-from-file=env.json
```

O `env.json` não vai para o git. A chave publishable/anon é pública por natureza: quem
protege os dados são as políticas de RLS do banco.

## Versão web / iPhone

A cada mudança na `main`, o workflow **Deploy Web** publica o app em
<https://thns7.github.io/Starlit-App/>. No iPhone, abra o link no Safari →
**Compartilhar → Adicionar à Tela de Início** para usar em tela cheia, como um app.

Para gerar o APK de release:

```bash
flutter build apk --release --dart-define-from-file=env.json
```
