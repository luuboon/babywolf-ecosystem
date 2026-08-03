// Acceso a la API pública del blog BabyWolf.
// GET /api/posts no lleva API key: no hay ningún secreto en este archivo.

const API_BASE = 'https://babywolf-blog-production.up.railway.app/api';

async function cargarNoticias() {
  const res = await fetch(`${API_BASE}/posts`);
  if (!res.ok) throw new Error(`El servidor respondió ${res.status}`);

  const data = await res.json();
  if (!Array.isArray(data)) throw new Error('Respuesta inesperada de la API');

  return data.map(normalizar);
}

/// Deja cada noticia en una forma predecible. Todo se fuerza a string porque
/// más adelante se pinta con textContent, nunca con innerHTML.
function normalizar(p) {
  return {
    id: String(p.id ?? ''),
    title: String(p.title ?? 'Sin título'),
    slug: String(p.slug ?? ''),
    content: String(p.content ?? ''),
    category: String(p.category ?? 'general'),
    cover: urlSegura(p.cover_image_url),
    fecha: formatearFecha(p.created_at),
  };
}

/// Sólo se acepta https. Evita que un `javascript:` o un `data:` acabe
/// inyectado en una regla CSS de background-image.
function urlSegura(u) {
  if (typeof u !== 'string' || u === '') return '';
  try {
    const parsed = new URL(u);
    return parsed.protocol === 'https:' ? parsed.href : '';
  } catch {
    return '';
  }
}

function formatearFecha(iso) {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  return d.toLocaleDateString('es-MX', {
    day: '2-digit',
    month: 'long',
    year: 'numeric',
  });
}
