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

/* Cria a conexão. Precisa que a tag script do Supabase (CDN)
   venha ANTES desta, senão window.supabase não existe ainda. */
window.db = (window.supabase && window.supabase.createClient)
  ? window.supabase.createClient(window.BANCO.url, window.BANCO.chave)
  : null;

if (!window.db) {
  console.warn('O Supabase não carregou. Confira se a tag script do CDN vem antes de js/banco.js.');
}

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
