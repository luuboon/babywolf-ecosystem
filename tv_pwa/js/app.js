// BabyWolf TV — orquesta datos, foco y sincronización con el teléfono.

const CARDS = ['card0', 'card1', 'card2', 'card3'];

let noticias = [];
let focoIdx = 0;

// ── Arranque ────────────────────────────────────────────────────
window.addEventListener('DOMContentLoaded', iniciar);

async function iniciar() {
  registrarServiceWorker();
  arrancarReloj();

  // El foco actualiza el titular; OK confirma y cambia el fondo.
  document.addEventListener('card-focus', (e) => {
    focoIdx = CARDS.indexOf(e.detail.cardId);
    pintarHero(noticias[focoIdx]);
  });
  document.addEventListener('card-select', (e) => {
    seleccionar(CARDS.indexOf(e.detail.cardId));
  });

  // Lo que pase en el teléfono se refleja aquí.
  escucharCanal(irASlug);
  seguirTelefono(irASlug);

  await cargar();
}

async function cargar() {
  const estado = document.getElementById('estadoDatos');
  try {
    const todas = await cargarNoticias();
    // El grid es de 4: se muestran las más recientes.
    noticias = todas.slice(0, 4);

    if (noticias.length === 0) {
      estado.textContent = 'No hay noticias publicadas';
      return;
    }

    noticias.forEach(pintarCard);
    seleccionar(0);
    estado.classList.remove('error');
    estado.textContent = `${noticias.length} noticias · actualizado ${horaCorta()}`;
  } catch (err) {
    // Sin red la app sigue en pie: el service worker ya sirvió la estructura.
    estado.classList.add('error');
    estado.textContent = `Sin conexión con la API (${err.message})`;
    console.error(err);
  }
}

// ── Pintado ─────────────────────────────────────────────────────

/// Siempre textContent, nunca innerHTML: el contenido viene de la API y no
/// debe poder inyectar marcado en la pantalla.
function pintarCard(noticia, i) {
  const card = document.getElementById(CARDS[i]);
  if (!card) return;

  card.querySelector('.card-cat').textContent = noticia.category.toUpperCase();
  card.querySelector('.card-titulo').textContent = noticia.title;
  card.querySelector('.card-fecha').textContent = noticia.fecha;
  card.setAttribute('aria-label', `${noticia.category}: ${noticia.title}`);
}

function pintarHero(noticia) {
  if (!noticia) return;
  document.getElementById('heroMeta').textContent =
    `${noticia.category.toUpperCase()} · ${noticia.fecha}`;
  document.getElementById('heroTitulo').textContent = noticia.title;
}

function seleccionar(i) {
  const noticia = noticias[i];
  if (!noticia) return;

  focoIdx = i;
  if (CARDS[i]) moverFoco(CARDS[i]);
  pintarHero(noticia);
  ponerFondo(noticia.cover);
}

/// Cambia el recurso multimedia de fondo. Si la portada no carga, se queda el
/// color sólido: la pantalla nunca se ve rota.
function ponerFondo(url) {
  const bg = document.getElementById('bgImage');
  if (!url) {
    bg.style.backgroundImage = 'none';
    return;
  }

  const img = new Image();
  img.onload = () => {
    bg.style.backgroundImage = `url("${encodeURI(url)}")`;
  };
  img.onerror = () => {
    bg.style.backgroundImage = 'none';
    console.warn('Portada no disponible, se usa el fondo sólido:', url);
  };
  img.src = url;
}

/// Enfoca la noticia que el teléfono está mostrando.
function irASlug({ slug }) {
  const i = noticias.findIndex((n) => n.slug === slug);
  if (i >= 0) seleccionar(i);
}

// ── Header ──────────────────────────────────────────────────────
function arrancarReloj() {
  const pintar = () => {
    const ahora = new Date();
    document.getElementById('reloj').textContent =
      `${horaCorta()} · ${ahora.toLocaleDateString('es-MX', {
        weekday: 'long',
        day: '2-digit',
        month: 'long',
      })}`;
  };
  pintar();
  setInterval(pintar, 1000);
}

function horaCorta() {
  return new Date().toLocaleTimeString('es-MX', {
    hour: '2-digit',
    minute: '2-digit',
  });
}

// ── PWA ─────────────────────────────────────────────────────────
function registrarServiceWorker() {
  if (!('serviceWorker' in navigator)) return;
  navigator.serviceWorker
    .register('./sw.js')
    .catch((err) => console.error('No se pudo registrar el SW:', err));
}
