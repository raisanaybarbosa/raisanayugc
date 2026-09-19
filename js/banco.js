/* ============================================================
   CONEXÃO COM O BANCO (Supabase)

   Este arquivo guarda o endereço do projeto e a chave PÚBLICA.
   É o único lugar onde esses dois dados aparecem. Se um dia
   você trocar de projeto no Supabase, troque só aqui.

   A chave abaixo é a publishable (também chamada de anon).
   Ela pode ficar visível, porque quem protege os dados de
   verdade é a tranca RLS que está no arquivo banco.sql.

   NUNCA coloque aqui a chave secreta (service_role).
   ============================================================ */

window.BANCO = {
  url: 'https://ithyicmxhygqiuewmbwb.supabase.co',
  chave: 'sb_publishable_mbUPoqKuGcX49sYEDhAIYg_-xW3a2gv',
  email: 'raisanay.ugc@gmail.com'   // o e-mail que faz login no painel
};

/* Onde a sessão do login fica guardada.
   Escolhemos o lugar na mão, em vez de deixar no automático,
   porque o automático estava falhando em alguns navegadores. */
window.CHAVE_SESSAO = 'raisa-painel-sessao';

/* Uma gaveta de guardar que nunca quebra a página:
   tenta o localStorage e, se ele estiver bloqueado, usa a memória da aba. */
const gavetaDeMemoria = {};
window.gaveta = {
  getItem: function (k) {
    try { const v = window.localStorage.getItem(k); if (v != null) return v; } catch (e) {}
    try { const v = window.sessionStorage.getItem(k); if (v != null) return v; } catch (e) {}
    return gavetaDeMemoria[k] != null ? gavetaDeMemoria[k] : null;
  },
  setItem: function (k, v) {
    gavetaDeMemoria[k] = v;
    try { window.localStorage.setItem(k, v); } catch (e) {}
    try { window.sessionStorage.setItem(k, v); } catch (e) {}
  },
  removeItem: function (k) {
    delete gavetaDeMemoria[k];
    try { window.localStorage.removeItem(k); } catch (e) {}
    try { window.sessionStorage.removeItem(k); } catch (e) {}
  }
};

/* Cria a conexão. Precisa que a tag script do Supabase (CDN)
   venha ANTES desta, senão window.supabase não existe ainda. */
window.db = (window.supabase && window.supabase.createClient)
  ? window.supabase.createClient(window.BANCO.url, window.BANCO.chave, {
      auth: {
        persistSession: true,        // guardar a sessão entre as páginas
        autoRefreshToken: true,      // renovar sozinho antes de vencer
        detectSessionInUrl: true,    // ler o link do e-mail de recuperação
        storage: window.gaveta,      // guardar na nossa gaveta
        storageKey: window.CHAVE_SESSAO
      }
    })
  : null;

if (!window.db) {
  console.warn('O Supabase não carregou. Confira se a tag script do CDN vem antes de js/banco.js.');
}

/* ------------------------------------------------------------
   CÓPIA DE SEGURANÇA DA SESSÃO
   Guardamos por fora só o par de chaves da sessão. Se por algum
   motivo a biblioteca perder a sessão ao trocar de página, o
   painel reconstrói a partir daqui em vez de te mandar de volta.
   ------------------------------------------------------------ */
window.CHAVE_COPIA = 'raisa-painel-copia';

window.guardarCopiaDaSessao = function (sessao) {
  if (!sessao || !sessao.access_token) return;
  window.gaveta.setItem(window.CHAVE_COPIA, JSON.stringify({
    access_token: sessao.access_token,
    refresh_token: sessao.refresh_token
  }));
};

window.apagarCopiaDaSessao = function () {
  window.gaveta.removeItem(window.CHAVE_COPIA);
  window.gaveta.removeItem(window.CHAVE_SESSAO);
};

/* Tenta achar a sessão. Se não achar, tenta reconstruir pela cópia. */
window.acharSessao = async function () {
  if (!window.db) return null;
  try {
    const { data } = await window.db.auth.getSession();
    if (data && data.session) return data.session;
  } catch (e) {}
  let copia = null;
  try { copia = JSON.parse(window.gaveta.getItem(window.CHAVE_COPIA) || 'null'); } catch (e) {}
  if (!copia || !copia.access_token) return null;
  try {
    const { data, error } = await window.db.auth.setSession(copia);
    if (error) { window.apagarCopiaDaSessao(); return null; }
    return data ? data.session : null;
  } catch (e) { return null; }
};

/* ------------------------------------------------------------
   AJUDANTES usados pelo painel e pelo site.
   Servem para o painel nunca abrir em branco quando faltar
   uma tabela ou um campo no banco.
   ------------------------------------------------------------ */

/* Diz se o erro é "essa tabela não existe" ou "esse campo não existe" */
window.faltaNoBanco = function (erro) {
  if (!erro) return null;
  const t = ((erro.message || '') + ' ' + (erro.details || '') + ' ' + (erro.hint || '')).toLowerCase();
  if (erro.code === '42P01' || erro.code === 'PGRST205' || t.includes('does not exist') || t.includes('schema cache')) {
    return true;
  }
  return false;
};

/* Faz uma leitura sem nunca derrubar a página.
   Devolve sempre { dados: [], erro: texto ou null } */
window.lerTabela = async function (tabela, montar) {
  if (!window.db) return { dados: [], erro: 'Sem conexão com o banco.' };
  try {
    let q = window.db.from(tabela).select('*');
    if (montar) q = montar(q);
    const { data, error } = await q;
    if (error) {
      return {
        dados: [],
        erro: window.faltaNoBanco(error)
          ? 'A tabela "' + tabela + '" ainda não existe no banco. Rode o arquivo banco.sql no Supabase.'
          : 'Não consegui ler "' + tabela + '": ' + (error.message || 'erro desconhecido')
      };
    }
    return { dados: data || [], erro: null };
  } catch (e) {
    return { dados: [], erro: 'Não consegui falar com o banco agora.' };
  }
};
