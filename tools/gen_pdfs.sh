#!/usr/bin/env bash
# Convierte los documentos de docs/ a PDF, listos para firmar a mano.
#
# El PDF es el entregable firmado; el Markdown sigue siendo la fuente. Si
# cambias un .md, vuelve a correr esto y firma el PDF nuevo.
#
#   ./tools/gen_pdfs.sh
#
# Requiere pandoc y Google Chrome.

set -euo pipefail

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
SALIDA="$RAIZ/docs/pdf"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
CSS="$(mktemp -t babywolf-pdf).css"

mkdir -p "$SALIDA"

cat > "$CSS" <<'EOF'
@page { margin: 18mm 16mm; }
body {
  font-family: -apple-system, "Helvetica Neue", Arial, sans-serif;
  font-size: 10.5pt;
  line-height: 1.5;
  color: #1a1a1a;
  max-width: none;
}
h1 { font-size: 19pt; border-bottom: 3px solid #e94560; padding-bottom: 6px; }
h2 { font-size: 14pt; margin-top: 22px; color: #16213e; }
h3 { font-size: 11.5pt; margin-top: 16px; color: #16213e; }
/* Un caso de prueba no debería partirse entre dos páginas. */
h3, h2 { break-after: avoid; }
table {
  border-collapse: collapse;
  width: 100%;
  margin: 10px 0;
  font-size: 9.5pt;
  break-inside: avoid;
}
th, td { border: 1px solid #ccc; padding: 5px 8px; text-align: left; vertical-align: top; }
th { background: #16213e; color: #fff; }
tr:nth-child(even) td { background: #f6f7fa; }
code {
  font-family: "SF Mono", Menlo, monospace;
  font-size: 9pt;
  background: #f2f3f7;
  padding: 1px 4px;
  border-radius: 3px;
}
pre {
  background: #f6f7fa;
  border-left: 3px solid #e94560;
  padding: 9px 12px;
  overflow-x: auto;
  break-inside: avoid;
}
pre code { background: none; padding: 0; }
blockquote { border-left: 3px solid #ccc; margin-left: 0; padding-left: 12px; color: #555; }
hr { border: none; border-top: 1px solid #ddd; margin: 20px 0; }
a { color: #16213e; }

/* Bloque de firma: "Alumno/Fecha" y "Firma" son dos párrafos, y el salto de
   página no debe caer ni dentro de ellos ni entre ellos. Sin el break-after
   la firma acaba huérfana en una página en blanco. */
body > p:nth-last-of-type(2) {
  margin-top: 34px;
  padding-top: 26px;
  border-top: 1px solid #999;
  break-inside: avoid;
  break-after: avoid;
}
/* Espacio real para la firma manuscrita. */
body > p:last-of-type {
  margin-top: 22px;
  break-inside: avoid;
}
EOF

for md in SEGURIDAD PLAN_PRUEBAS CONFIGURACION; do
  html="$(mktemp -t "$md").html"
  pandoc "$RAIZ/docs/$md.md" \
    --standalone --embed-resources \
    --metadata title="" \
    --css "$CSS" \
    -o "$html"

  "$CHROME" --headless --disable-gpu --no-pdf-header-footer \
    --print-to-pdf="$SALIDA/$md.pdf" "$html" 2>/dev/null || true

  rm -f "$html"
  printf '  docs/pdf/%-16s %s\n' "$md.pdf" "$(du -h "$SALIDA/$md.pdf" | cut -f1)"
done

rm -f "$CSS"
echo
echo "Listos para firmar en Vista Previa:"
echo "  Herramientas -> Anotar -> Firma -> Gestionar firmas"
