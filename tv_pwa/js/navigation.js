// Navegación con D-pad sobre el grid 2x2.
//
// El mapa es explícito: en los bordes simplemente no hay destino, así que el
// foco se queda donde está en vez de perderse.

const NAV_MAP = {
  card0: { right: 'card1', down: 'card2' },
  card1: { left: 'card0', down: 'card3' },
  card2: { right: 'card3', up: 'card0' },
  card3: { left: 'card2', up: 'card1' },
};

let focoActual = 'card0';

function moverFoco(siguienteId) {
  const anterior = document.getElementById(focoActual);
  if (anterior) {
    anterior.classList.remove('focused');
    anterior.setAttribute('tabindex', '-1');
  }

  focoActual = siguienteId;
  const el = document.getElementById(focoActual);
  if (!el) return;

  el.classList.add('focused');
  el.setAttribute('tabindex', '0');
  el.focus({ preventScroll: true });

  el.dispatchEvent(
    new CustomEvent('card-focus', { bubbles: true, detail: { cardId: focoActual } })
  );
}

document.addEventListener('keydown', (e) => {
  const dir = {
    ArrowRight: 'right',
    ArrowLeft: 'left',
    ArrowDown: 'down',
    ArrowUp: 'up',
  }[e.key];

  if (dir) {
    e.preventDefault();
    const siguiente = NAV_MAP[focoActual]?.[dir];
    // Sin destino significa borde del grid: el foco no se mueve ni se rompe.
    if (siguiente) moverFoco(siguiente);
    return;
  }

  if (e.key === 'Enter' || e.key === ' ') {
    e.preventDefault();
    const card = document.getElementById(focoActual);
    card?.dispatchEvent(
      new CustomEvent('card-select', { bubbles: true, detail: { cardId: focoActual } })
    );
  }
});
