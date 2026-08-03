// Sincronización con el teléfono.
//
// Dos caminos, ambos con la misma validación:
//   1. BroadcastChannel — entre pestañas de esta misma PWA.
//   2. Polling al hub   — es por donde llega lo que hace la app Flutter.
//
// Regla de seguridad: ningún mensaje llega a la UI sin pasar por
// validarMensaje(). Un mensaje de origen distinto se descarta sin abrirlo.

const HUB_URL = 'http://localhost:8090';
const NOMBRE_CANAL = 'babywolf-sync';

const canal = new BroadcastChannel(NOMBRE_CANAL);

/// Valida el ORIGEN y luego la FORMA del mensaje. Si algo no cuadra, se
/// descarta: nunca se confía en lo que llega por el canal.
function escucharCanal(alRecibir) {
  canal.onmessage = (event) => {
    // BroadcastChannel es same-origin por diseño, pero la validación es
    // explícita: si el origen no es el nuestro, el mensaje no se procesa.
    if (event.origin && event.origin !== location.origin) {
      console.warn('[seguridad] mensaje descartado, origen no confiable:', event.origin);
      return;
    }

    const msg = validarMensaje(event.data);
    if (!msg) {
      console.warn('[seguridad] mensaje descartado, forma inválida');
      return;
    }
    alRecibir(msg);
  };
}

/// Sólo pasan objetos con un slug razonable. Corta payloads inflados y
/// cualquier cosa que no sea texto plano.
function validarMensaje(data) {
  if (!data || typeof data !== 'object') return null;
  if (typeof data.slug !== 'string') return null;
  if (data.slug.length === 0 || data.slug.length > 200) return null;

  const category =
    typeof data.category === 'string' && data.category.length <= 60
      ? data.category
      : null;

  return { slug: data.slug, category };
}

/// Consulta el hub cada [cadaMs] y avisa cuando el teléfono cambió de noticia.
/// Si el hub no está corriendo, la TV sigue mostrando sus noticias.
function seguirTelefono(alCambiar, cadaMs = 1000) {
  let ultimoTs = 0;

  setInterval(async () => {
    let estado;
    try {
      const res = await fetch(`${HUB_URL}/state`, { cache: 'no-store' });
      if (!res.ok) return;
      estado = await res.json();
    } catch {
      return; // Hub apagado: la sincronía es un extra, no un requisito de arranque.
    }

    if (!estado || estado.ts === ultimoTs) return;
    ultimoTs = estado.ts;

    const msg = validarMensaje(estado);
    if (!msg) return;

    alCambiar(msg);
    canal.postMessage(msg); // Replica a otras pestañas de esta misma PWA.
  }, cadaMs);
}
