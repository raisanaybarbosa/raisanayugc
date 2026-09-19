-- ============================================================
--  BANCO DO PAINEL DA RAISA
--  Portfólio UGC · raisanaybarbosa.github.io/raisanayugc
--
--  ONDE COLAR ISTO:
--  1. Entre em supabase.com e abra o seu projeto.
--  2. No menu da esquerda, clique em "SQL Editor".
--  3. Clique em "New query".
--  4. Cole TUDO o que está neste arquivo, de cima até embaixo.
--  5. Clique em "Run" (ou aperte Ctrl e Enter juntos).
--  6. Deve aparecer "Success. No rows returned". É isso mesmo.
--
--  Pode rodar este arquivo mais de uma vez sem medo. Ele foi
--  escrito para não duplicar nada nem apagar o que já existe.
-- ============================================================


-- ============================================================
--  BLOCO 1 · AS TABELAS
--  Cada tabela é uma "planilha" dentro do banco.
--  O campo id se preenche sozinho. O campo criado_em guarda
--  a data e a hora em que a linha nasceu, também sozinho.
-- ============================================================

-- Os vídeos do portfólio. É desta tabela que o seu site lê.
create table if not exists public.videos (
  id         uuid primary key default gen_random_uuid(),
  titulo     text not null,
  link       text,
  nicho      text,            -- beleza, fitness, maternidade, tech
  formato    text,            -- Vídeo UGC, Corte para anúncio, Fotos do produto, Unboxing
  marca      text,
  destaque   text,            -- o número forte, por exemplo "2,4M views"
  ordem      integer default 0,   -- menor aparece primeiro no site
  visivel    boolean default true,-- o olhinho do painel liga e desliga isto
  criado_em  timestamptz default now()
);

-- A sua base de contatos de empresa.
create table if not exists public.marcas (
  id              uuid primary key default gen_random_uuid(),
  nome            text not null,
  instagram       text,
  email           text,
  telefone        text,
  situacao        text default 'lead',   -- lead, conversando, cliente, parada
  obs             text,
  ultimo_contato  date,
  criado_em       timestamptz default now()
);

-- A sua agenda de gravar, editar e postar.
create table if not exists public.calendario (
  id         uuid primary key default gen_random_uuid(),
  titulo     text not null,
  marca      text,
  tipo       text default 'gravar',   -- gravar, editar, postar
  data       date not null,
  status     text default 'a fazer',  -- a fazer, feito
  criado_em  timestamptz default now()
);

-- Os trabalhos fechados, com valor, prazo e pagamento.
create table if not exists public.campanhas (
  id         uuid primary key default gen_random_uuid(),
  campanha   text not null,
  cliente    text,
  tipo       text default 'Conteúdo',   -- Conteúdo ou Publicidade
  status     text default 'Briefing',   -- Briefing, Roteiro, Aprovação Roteiro, Gravação, Edição, Aprovado, Entregue
  qtd        integer default 1,
  valor      numeric(12,2) default 0,
  prazo      date,
  pagamento  text default 'pendente',   -- pendente ou pago
  ativa      boolean default true,
  favorita   boolean default false,
  criado_em  timestamptz default now()
);

-- O que você já marcou no checklist do portfólio.
-- Uma linha por item marcado, identificado por uma chave de texto.
create table if not exists public.marcados (
  id         uuid primary key default gen_random_uuid(),
  chave      text not null unique,
  marcado    boolean default true,
  criado_em  timestamptz default now()
);

-- As visitas do seu portfólio, para as métricas do painel.
create table if not exists public.visitas (
  id      uuid primary key default gen_random_uuid(),
  data    timestamptz default now(),
  pagina  text,
  origem  text            -- direto, instagram, google, e por aí vai
);


-- ============================================================
--  BLOCO 2 · CAMPOS QUE PODEM FALTAR
--  Se você já tinha criado alguma tabela antes, estas linhas
--  acrescentam o que estiver faltando, sem apagar nada.
-- ============================================================

alter table public.videos     add column if not exists ordem integer default 0;
alter table public.videos     add column if not exists visivel boolean default true;
alter table public.videos     add column if not exists destaque text;
alter table public.marcas     add column if not exists ultimo_contato date;
alter table public.marcas     add column if not exists obs text;
alter table public.campanhas  add column if not exists favorita boolean default false;
alter table public.campanhas  add column if not exists ativa boolean default true;
alter table public.calendario add column if not exists status text default 'a fazer';
alter table public.visitas    add column if not exists origem text;


-- ============================================================
--  BLOCO 3 · ÍNDICES
--  Servem só para o painel abrir rápido quando a tabela crescer.
-- ============================================================

create index if not exists videos_ordem_idx      on public.videos (ordem);
create index if not exists marcas_situacao_idx   on public.marcas (situacao);
create index if not exists calendario_data_idx   on public.calendario (data);
create index if not exists campanhas_prazo_idx   on public.campanhas (prazo);
create index if not exists visitas_data_idx      on public.visitas (data);


-- ============================================================
--  BLOCO 4 · A TRANCA (RLS)
--
--  RLS quer dizer Row Level Security, segurança linha por linha.
--  Sem ela, qualquer pessoa com a chave pública leria tudo.
--  Com ela ligada e sem nenhuma permissão escrita, o banco nega
--  tudo por padrão. Quem libera é só o que vem depois.
--
--  A regra: quem entra com o SEU e-mail pode ler e escrever tudo.
--  Duas exceções, e só essas duas:
--    · qualquer pessoa pode INSERIR em marcas (o formulário do site)
--    · qualquer pessoa pode INSERIR em visitas (o contador de visita)
--  Ler, em qualquer tabela, só você.
-- ============================================================

-- Liga a tranca nas seis tabelas.
alter table public.videos     enable row level security;
alter table public.marcas     enable row level security;
alter table public.calendario enable row level security;
alter table public.campanhas  enable row level security;
alter table public.marcados   enable row level security;
alter table public.visitas    enable row level security;

-- Uma funçãozinha que responde: "quem está pedindo é a Raisa?"
-- Ela olha o e-mail de quem fez login. Se for outro e-mail, responde não.
create or replace function public.sou_a_dona()
returns boolean
language sql
stable
security invoker
set search_path = public
as $$
  select coalesce(auth.jwt() ->> 'email', '') = 'raisanay.ugc@gmail.com'
$$;

-- Apaga permissões antigas com o mesmo nome, para poder rodar de novo.
drop policy if exists dona_tudo_videos     on public.videos;
drop policy if exists dona_tudo_marcas     on public.marcas;
drop policy if exists dona_tudo_calendario on public.calendario;
drop policy if exists dona_tudo_campanhas  on public.campanhas;
drop policy if exists dona_tudo_marcados   on public.marcados;
drop policy if exists dona_tudo_visitas    on public.visitas;
drop policy if exists site_insere_marca    on public.marcas;
drop policy if exists site_insere_visita   on public.visitas;

-- VIDEOS: só a dona, logada, faz tudo. Deslogado não lê nada.
create policy dona_tudo_videos on public.videos
  for all to authenticated
  using (public.sou_a_dona())
  with check (public.sou_a_dona());

-- MARCAS: só a dona faz tudo.
create policy dona_tudo_marcas on public.marcas
  for all to authenticated
  using (public.sou_a_dona())
  with check (public.sou_a_dona());

-- MARCAS, exceção 1: qualquer visitante pode INSERIR, e só inserir.
-- É assim que o formulário do seu site cria um lead. Ele não lê nada.
create policy site_insere_marca on public.marcas
  for insert to anon
  with check (situacao = 'lead');

-- CALENDARIO: só a dona.
create policy dona_tudo_calendario on public.calendario
  for all to authenticated
  using (public.sou_a_dona())
  with check (public.sou_a_dona());

-- CAMPANHAS: só a dona.
create policy dona_tudo_campanhas on public.campanhas
  for all to authenticated
  using (public.sou_a_dona())
  with check (public.sou_a_dona());

-- MARCADOS: só a dona.
create policy dona_tudo_marcados on public.marcados
  for all to authenticated
  using (public.sou_a_dona())
  with check (public.sou_a_dona());

-- VISITAS: só a dona lê.
create policy dona_tudo_visitas on public.visitas
  for all to authenticated
  using (public.sou_a_dona())
  with check (public.sou_a_dona());

-- VISITAS, exceção 2: qualquer visitante pode INSERIR, e só inserir.
create policy site_insere_visita on public.visitas
  for insert to anon
  with check (true);


-- ============================================================
--  BLOCO 5 · UMA LINHA DE EXEMPLO EM CADA LISTA
--
--  São só para você ver o formato e entender onde vai cada coisa.
--  Todas estão escritas com a palavra "exemplo".
--  Pode apagar todas de uma vez rodando, no SQL Editor:
--
--    delete from public.videos     where titulo   like '%(exemplo)%';
--    delete from public.marcas     where nome     like '%(exemplo)%';
--    delete from public.calendario where titulo   like '%(exemplo)%';
--    delete from public.campanhas  where campanha like '%(exemplo)%';
--
--  O vídeo de exemplo nasce com visivel = false, então ele
--  aparece no painel mas NÃO aparece no seu site.
-- ============================================================

insert into public.videos (titulo, link, nicho, formato, marca, destaque, ordem, visivel)
select 'Primeiro vídeo (exemplo)', 'https://instagram.com/', 'beleza', 'Vídeo UGC', 'Marca de exemplo', '0 views', 1, false
where not exists (select 1 from public.videos);

insert into public.marcas (nome, instagram, email, telefone, situacao, obs, ultimo_contato)
select 'Marca de exemplo (exemplo)', '@marcadeexemplo', 'contato@exemplo.com', '62999999999', 'lead', 'Apague esta linha quando cadastrar a primeira marca de verdade.', current_date
where not exists (select 1 from public.marcas);

insert into public.calendario (titulo, marca, tipo, data, status)
select 'Gravar primeiro vídeo (exemplo)', 'Marca de exemplo', 'gravar', current_date, 'a fazer'
where not exists (select 1 from public.calendario);

insert into public.campanhas (campanha, cliente, tipo, status, qtd, valor, prazo, pagamento, ativa, favorita)
select 'Campanha de teste (exemplo)', 'Marca de exemplo', 'Conteúdo', 'Briefing', 1, 0, current_date + 7, 'pendente', true, false
where not exists (select 1 from public.campanhas);

-- As tabelas marcados e visitas nascem vazias de propósito:
-- marcados enche quando você marcar o checklist,
-- visitas enche quando as pessoas visitarem o seu portfólio.
