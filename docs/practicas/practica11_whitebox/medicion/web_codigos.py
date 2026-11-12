#!/usr/bin/env python3
"""Práctica 11 · Fase 3 — WEB-01…WEB-06 contra el backend desplegado.

Solo biblioteca estándar. Ejecuta peticiones reales y registra código HTTP,
tipo de contenido, tamaño y forma del JSON. No envía credenciales reales:
la prueba 403 usa un token de lector SOLO si lo pasas en BW_LECTOR_JWT.

Uso:  python3 web_codigos.py [URL_BASE]
      BW_LECTOR_JWT=<access_token de una cuenta de lector> python3 web_codigos.py
"""
import json, os, re, ssl, sys, time, urllib.error, urllib.request, platform, datetime

BASE = (sys.argv[1] if len(sys.argv) > 1 else "https://babywolf-blog-production.up.railway.app/api").rstrip("/")
LECTOR = os.environ.get("BW_LECTOR_JWT", "")
SALA = "WB11-" + datetime.datetime.now().strftime("%H%M%S")
ctx = ssl.create_default_context()
filas, hallazgos = [], []


def pedir(metodo, ruta, cuerpo=None, cab=None, crudo=None):
    url = BASE + ruta if ruta.startswith("/") else ruta
    datos = crudo if crudo is not None else (json.dumps(cuerpo).encode() if cuerpo is not None else None)
    req = urllib.request.Request(url, data=datos, method=metodo, headers={"Accept": "application/json", **(cab or {})})
    if datos is not None and "Content-Type" not in req.headers:
        req.add_header("Content-Type", "application/json")
    t0 = time.perf_counter()
    try:
        with urllib.request.urlopen(req, timeout=20, context=ctx) as r:
            cuerpo_b, codigo, h = r.read(), r.status, dict(r.headers)
    except urllib.error.HTTPError as e:
        cuerpo_b, codigo, h = e.read(), e.code, dict(e.headers)
    except Exception as e:  # sin red, DNS, TLS…
        return {"codigo": 0, "ms": (time.perf_counter() - t0) * 1000, "bytes": 0, "ctype": "", "texto": str(e), "json": None, "h": {}}
    ms = (time.perf_counter() - t0) * 1000
    texto = cuerpo_b.decode("utf-8", "replace")
    try:
        js = json.loads(texto)
    except Exception:
        js = None
    return {"codigo": codigo, "ms": ms, "bytes": len(cuerpo_b), "ctype": h.get("Content-Type", h.get("content-type", "")), "texto": texto, "json": js, "h": h}


def caso(id_, descripcion, esperado, r, ok, nota=""):
    estado = "PASA" if ok else "FALLA"
    filas.append({"id": id_, "caso": descripcion, "esperado": esperado, "obtenido": r["codigo"], "ms": round(r["ms"], 1),
                  "bytes": r["bytes"], "tipo": r["ctype"].split(";")[0], "estado": estado, "nota": nota})
    print(f"{id_:7s} {estado:5s} esperado={esperado!s:4} obtenido={r['codigo']!s:4} {r['ms']:7.1f} ms {r['bytes']:7d} B  {descripcion}" + (f"  [{nota}]" if nota else ""))


print(f"# WEB — {BASE} — {datetime.datetime.now().astimezone().isoformat(timespec='seconds')}")
print(f"# Cliente: {platform.platform()} · Python {platform.python_version()}\n")

# ── WEB-01 · respuestas exitosas ─────────────────────────────
r = pedir("GET", "/posts")
lista = r["json"] if isinstance(r["json"], list) else []
campos = {"id", "title", "slug", "content", "published", "created_at"}
ok = r["codigo"] == 200 and isinstance(r["json"], list) and all(campos <= set(p) for p in lista)
caso("WEB-01a", "GET /posts → lista de noticias", 200, r, ok, f"{len(lista)} noticias; JSON con {sorted(set().union(*[set(p) for p in lista]) if lista else [])}")
posts_resp = r

r = pedir("GET", "/consulta/url")
okurl = r["codigo"] == 200 and isinstance(r["json"], dict) and {"url", "expira", "ttl_segundos"} <= set(r["json"])
caso("WEB-01b", "GET /consulta/url → URL firmada", 200, r, okurl, f"ttl={r['json'].get('ttl_segundos') if r['json'] else '?'}")
url_firmada = r["json"]["url"] if okurl else None
if url_firmada:
    r = pedir("GET", url_firmada)
    claves = {"sitio", "generado", "total_noticias", "por_categoria", "ultimas"}
    caso("WEB-01c", "GET URL firmada → resumen", 200, r, r["codigo"] == 200 and isinstance(r["json"], dict) and claves <= set(r["json"]))
    if not url_firmada.startswith("https://"):
        hallazgos.append("La URL firmada no es https (revisar X-Forwarded-Proto / PUBLIC_BASE_URL).")

r = pedir("POST", f"/connect/salas/{SALA}/mensajes", {"emisor": "A", "dispositivo": "wb11", "texto": "prueba white box"})
caso("WEB-01d", "POST /connect/salas/:sala/mensajes → crea", 201, r, r["codigo"] == 201 and isinstance(r["json"], dict) and "id" in r["json"])
r = pedir("GET", f"/connect/salas/{SALA}/mensajes")
caso("WEB-01e", "GET mensajes de la sala (persistencia)", 200, r, r["codigo"] == 200 and r["json"] and len(r["json"].get("mensajes", [])) == 1)
r = pedir("DELETE", f"/connect/salas/{SALA}/mensajes")
caso("WEB-01f", "DELETE mensajes de la sala → sin cuerpo", 204, r, r["codigo"] == 204 and r["bytes"] == 0)

# ── WEB-02 · errores ─────────────────────────────────────────
r = pedir("GET", "/posts/slug-que-no-existe-wb11")
caso("WEB-02a", "GET post inexistente", 404, r, r["codigo"] == 404 and isinstance(r["json"], dict) and "error" in r["json"])
r = pedir("GET", "/ruta-que-no-existe")
caso("WEB-02b", "GET ruta inexistente: ¿JSON o texto?", 404, r, r["codigo"] == 404 and r["json"] is not None,
     "" if r["json"] is not None else f"respuesta no JSON ({r['ctype'] or 'sin tipo'}): {r['texto'][:40]!r}")
if r["json"] is None and r["codigo"] == 404:
    hallazgos.append("Una ruta inexistente responde texto plano (\"404 page not found\"), no el {\"error\": …} del resto de la API.")
r = pedir("POST", f"/connect/salas/{SALA}/mensajes", crudo=b"{esto no es json")
caso("WEB-02c", "POST con JSON mal formado", 400, r, r["codigo"] == 400)
r = pedir("GET", "/consulta/recurso")
caso("WEB-02d", "Recurso sin firma", 403, r, r["codigo"] == 403)
if url_firmada:
    alterada = re.sub(r"recurso=[^&]+", "recurso=otro", url_firmada)
    r = pedir("GET", alterada)
    caso("WEB-02e", "Prueba 3 de ConsultaWeb: URL con un parámetro cambiado", 403, r, r["codigo"] == 403)
    r = pedir("GET", re.sub(r"exp=\d+", "exp=9999999999", url_firmada))
    caso("WEB-02f", "URL con exp alargado (intentar revivirla)", 403, r, r["codigo"] == 403)

# ── WEB-03 · validación del backend ─────────────────────────
r = pedir("POST", f"/connect/salas/{SALA}/mensajes", {"emisor": "A", "texto": "   "})
caso("WEB-03a", "Mensaje vacío", 422, r, r["codigo"] == 422)
r = pedir("POST", f"/connect/salas/{SALA}/mensajes", {"emisor": "Z", "texto": "hola"})
caso("WEB-03b", "Emisor inválido", 422, r, r["codigo"] == 422)
r = pedir("POST", f"/connect/salas/{SALA}/mensajes", {"emisor": "A", "texto": "x" * 281})
caso("WEB-03c", "Texto de 281 caracteres (límite 280)", 422, r, r["codigo"] == 422)
r = pedir("POST", "/connect/salas/x/mensajes", {"emisor": "A", "texto": "hola"})
caso("WEB-03d", "Código de sala inválido", 422, r, r["codigo"] == 422)
r = pedir("POST", f"/connect/salas/{SALA}/mensajes", {"emisor": "A", "texto": "<script>alert(1)</script> ' OR 1=1 --"})
eco = r["json"].get("texto") if isinstance(r["json"], dict) else None
caso("WEB-03e", "Texto con HTML y SQL: se guarda como texto, sin ejecutarse", 201, r, r["codigo"] == 201 and eco is not None,
     "el servidor devuelve el texto tal cual (JSON escapa; la app lo muestra como Text)")
pedir("DELETE", f"/connect/salas/{SALA}/mensajes")

# ── WEB-04 · autenticación y autorización ───────────────────
for metodo, ruta, cuerpo in [("GET", "/admin/profile", None), ("GET", "/admin/users", None),
                             ("POST", "/admin/posts", {"title": "x", "content": "y"}),
                             ("POST", "/admin/upload", None), ("DELETE", "/admin/posts/x", None),
                             ("PATCH", "/admin/users/x/role", {"role": "admin"})]:
    r = pedir(metodo, ruta, cuerpo)
    caso("WEB-04a", f"{metodo} {ruta} sin token", 401, r, r["codigo"] == 401)
r = pedir("GET", "/admin/users", cab={"Authorization": "Bearer abc.def.ghi"})
caso("WEB-04b", "Token basura", 401, r, r["codigo"] == 401)
r = pedir("GET", "/admin/users", cab={"Authorization": "Token xyz"})
caso("WEB-04c", "Cabecera con esquema distinto de Bearer", 401, r, r["codigo"] == 401)
# alg=none: token sin firma
b64 = lambda d: __import__("base64").urlsafe_b64encode(json.dumps(d).encode()).rstrip(b"=").decode()
sin_firma = f"{b64({'alg': 'none', 'typ': 'JWT'})}.{b64({'sub': 'x', 'role': 'authenticated', 'app_metadata': {'role': 'admin'}})}."
r = pedir("GET", "/admin/users", cab={"Authorization": "Bearer " + sin_firma})
caso("WEB-04d", "JWT con alg=none y rol admin inventado", 401, r, r["codigo"] == 401)
# HS256 firmado con una clave vacía: sólo pasa si JWT_SECRET no está configurado
import hmac, hashlib
cuerpo_jwt = f"{b64({'alg': 'HS256', 'typ': 'JWT'})}.{b64({'sub': 'x', 'role': 'authenticated', 'app_metadata': {'role': 'admin'}})}"
firma = __import__("base64").urlsafe_b64encode(hmac.new(b"", cuerpo_jwt.encode(), hashlib.sha256).digest()).rstrip(b"=").decode()
r = pedir("GET", "/admin/users", cab={"Authorization": f"Bearer {cuerpo_jwt}.{firma}"})
caso("WEB-04e", "JWT HS256 firmado con clave vacía (¿JWT_SECRET configurado?)", 401, r, r["codigo"] == 401)
if r["codigo"] != 401:
    hallazgos.append("CRÍTICO: un JWT firmado con clave vacía fue aceptado: JWT_SECRET no está configurado en el servidor.")

if LECTOR:
    cab = {"Authorization": "Bearer " + LECTOR}
    r = pedir("GET", "/admin/users", cab=cab)
    caso("WEB-04f", "Lector autenticado pide la lista de usuarios (rol real en BD)", 403, r, r["codigo"] == 403)
    r = pedir("PATCH", "/admin/users/00000000-0000-0000-0000-000000000000/role", {"role": "admin"}, cab=cab)
    caso("WEB-04g", "Lector intenta cambiar un rol", 403, r, r["codigo"] in (401, 403), f"código {r['codigo']}")
    # Sonda sin efectos: cuerpo vacío. Si responde 403, hay control de rol; si llega a validar el cuerpo (400/500), no lo hay.
    r = pedir("POST", "/admin/posts", {}, cab=cab)
    caso("WEB-04h", "Lector autenticado llega al alta de posts (sonda con cuerpo vacío, no crea nada)", 403, r, r["codigo"] == 403,
         "" if r["codigo"] == 403 else f"LLEGÓ AL CONTROLADOR (código {r['codigo']}): el grupo /admin sólo valida el JWT, no el rol")
    if r["codigo"] != 403:
        hallazgos.append(f"POST /admin/posts con una cuenta de lector respondió {r['codigo']} y no 403: el endpoint no comprueba el rol admin (también /admin/upload comparte el grupo).")
else:
    print("(sin BW_LECTOR_JWT: se omiten WEB-04f/g/h, la prueba de 403 con una cuenta real)")

# ── WEB-05 · latencia (resumen; el detalle está en red_rendimiento.py) ──
tiempos = []
for _ in range(10):
    tiempos.append(pedir("GET", "/posts")["ms"])
print(f"\nWEB-05  10 × GET /posts: min {min(tiempos):.0f} · prom {sum(tiempos)/10:.0f} · max {max(tiempos):.0f} ms")
filas.append({"id": "WEB-05", "caso": "Latencia HTTP, 10 solicitudes a /posts", "esperado": "prom ≤ 500 ms", "obtenido": round(sum(tiempos) / 10, 1),
              "ms": round(sum(tiempos) / 10, 1), "bytes": posts_resp["bytes"], "tipo": "", "estado": "PASA" if sum(tiempos) / 10 <= 500 else "FALLA", "nota": f"min {min(tiempos):.0f} / max {max(tiempos):.0f}"})

# ── WEB-06 · consistencia y exposición de datos ─────────────
patrones = {"JWT": r"eyJ[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{15,}", "contraseña": r"(?i)\"(password|passwd|contrase[nñ]a)\"",
            "secreto": r"(?i)(secret|service_role|api[_-]?key)", "hash": r"\$2[aby]\$|\"[a-z_]*hash[a-z_]*\""}
vistos = {"/posts": posts_resp["texto"]}
for ruta in ("/consulta/url",):
    vistos[ruta] = pedir("GET", ruta)["texto"]
ok = True
for ruta, texto in vistos.items():
    for nombre, pat in patrones.items():
        if re.search(pat, texto):
            ok = False
            hallazgos.append(f"{ruta}: la respuesta coincide con el patrón '{nombre}'.")
caso("WEB-06a", "Las respuestas públicas no contienen JWT, contraseñas, secretos ni hashes", "sin coincidencias", posts_resp, ok)
tiene_correo = bool(re.search(r"[\w.+-]+@[\w-]+\.[\w.]+", posts_resp["texto"]))
print(f"WEB-06b /posts incluye correos electrónicos: {'SÍ' if tiene_correo else 'no'}")
errores = [pedir("GET", "/posts/no-existe")["json"], pedir("POST", f"/connect/salas/{SALA}/mensajes", crudo=b"x")["json"]]
forma = all(isinstance(e, dict) and set(e) == {"error"} for e in errores)
print(f"WEB-06c forma de los errores = {{\"error\": texto}}: {'sí' if forma else 'NO'}  {errores}")
cabs = posts_resp["h"]
faltan = [h for h in ("X-Content-Type-Options", "Strict-Transport-Security", "Content-Security-Policy") if h.lower() not in {k.lower() for k in cabs}]
print(f"WEB-06d cabeceras de seguridad ausentes en /posts: {faltan or 'ninguna'}")
print(f"WEB-06e CORS Access-Control-Allow-Origin: {cabs.get('Access-Control-Allow-Origin', cabs.get('access-control-allow-origin', '(no enviada)'))}")

print("\n## Hallazgos")
for h in hallazgos or ["(ninguno automático)"]:
    print("-", h)
pasan = sum(1 for f in filas if f["estado"] == "PASA")
print(f"\nResumen: {pasan}/{len(filas)} casos pasan")

os.makedirs(os.path.join(os.path.dirname(__file__), "..", "resultados"), exist_ok=True)
with open(os.path.join(os.path.dirname(__file__), "..", "resultados", "web_codigos.json"), "w", encoding="utf-8") as f:
    json.dump({"base": BASE, "fecha": datetime.datetime.now().astimezone().isoformat(), "cliente": platform.platform(),
               "casos": filas, "hallazgos": hallazgos}, f, ensure_ascii=False, indent=2)
