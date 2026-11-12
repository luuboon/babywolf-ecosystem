#!/usr/bin/env python3
"""Práctica 11 · Fase 5 — NET-01…NET-07: ping, latencia HTTP, tasas de
transferencia, 10 solicitudes consecutivas y carga controlada.

Solo biblioteca estándar. Cada número viene de una medición real hecha por
este script desde la máquina donde lo ejecutas; nada se estima.

Uso: python3 red_rendimiento.py [URL_BASE]
"""
import concurrent.futures as cf, datetime, json, os, platform, re, socket, ssl, statistics, subprocess, sys, time, urllib.parse

BASE = (sys.argv[1] if len(sys.argv) > 1 else "https://babywolf-blog-production.up.railway.app/api").rstrip("/")
U = urllib.parse.urlparse(BASE)
HOST, PUERTO = U.hostname, U.port or (443 if U.scheme == "https" else 80)
ctx = ssl.create_default_context()
SALA = "WB11-" + datetime.datetime.now().strftime("%H%M%S")
R = {"base": BASE, "fecha": datetime.datetime.now().astimezone().isoformat(), "cliente": platform.platform(),
     "python": platform.python_version()}


def pct(v, p):
    v = sorted(v)
    k = max(0, min(len(v) - 1, int(round(p / 100 * len(v) + 0.5)) - 1))  # método del rango más cercano
    return v[k]


def resumen(v):
    return {"n": len(v), "min": round(min(v), 1), "prom": round(statistics.mean(v), 1), "max": round(max(v), 1),
            "desv": round(statistics.pstdev(v), 1) if len(v) > 1 else 0.0, "p95": round(pct(v, 95), 1)}


def http(metodo, ruta, cuerpo=None, ctype="application/json", conexion_nueva=True):
    """Una petición HTTP/1.1 con desglose de tiempos (ms): dns, tcp, tls, ttfb, total."""
    t = {}
    t0 = time.perf_counter()
    info = socket.getaddrinfo(HOST, PUERTO, type=socket.SOCK_STREAM)[0]
    t["dns"] = (time.perf_counter() - t0) * 1000
    t1 = time.perf_counter()
    s = socket.create_connection(info[4][:2], timeout=20)
    t["tcp"] = (time.perf_counter() - t1) * 1000
    t2 = time.perf_counter()
    if U.scheme == "https":
        s = ctx.wrap_socket(s, server_hostname=HOST)
    t["tls"] = (time.perf_counter() - t2) * 1000
    cuerpo_b = b"" if cuerpo is None else (cuerpo if isinstance(cuerpo, bytes) else json.dumps(cuerpo).encode())
    cab = f"{metodo} {U.path}{ruta} HTTP/1.1\r\nHost: {HOST}\r\nAccept: application/json\r\nConnection: close\r\nUser-Agent: bw-p11\r\n"
    if cuerpo is not None:
        cab += f"Content-Type: {ctype}\r\nContent-Length: {len(cuerpo_b)}\r\n"
    t3 = time.perf_counter()
    cortado = None
    try:
        s.sendall(cab.encode() + b"\r\n" + cuerpo_b)
    except (BrokenPipeError, ConnectionResetError, ssl.SSLError, OSError) as e:
        cortado = type(e).__name__  # el servidor/borde cerró antes de recibir todo el cuerpo
    t["envio"] = (time.perf_counter() - t3) * 1000
    try:
        primero = s.recv(65536)
    except (ConnectionResetError, ssl.SSLError, OSError):
        primero = b""
    t["ttfb"] = (time.perf_counter() - t3) * 1000
    datos = [primero]
    while primero:
        try:
            b = s.recv(65536)
        except (ConnectionResetError, ssl.SSLError, OSError):
            break
        if not b:
            break
        datos.append(b)
    t["total"] = (time.perf_counter() - t0) * 1000
    s.close()
    crudo = b"".join(datos)
    cabecera, _, cuerpo_resp = crudo.partition(b"\r\n\r\n")
    m = re.match(rb"HTTP/1\.[01] (\d{3})", cabecera)
    codigo = int(m.group(1)) if m else 0
    chunked = b"transfer-encoding: chunked" in cabecera.lower()
    tam = len(cuerpo_resp)
    return {"codigo": codigo, "t": t, "bytes_cuerpo": tam, "bytes_total": len(crudo), "bytes_enviados": len(cab) + len(cuerpo_b), "chunked": chunked, "cortado": cortado}


# ── NET-01 · ping ────────────────────────────────────────────
print(f"# Medición de red — {R['fecha']}\n# Cliente: {R['cliente']} · destino {HOST}:{PUERTO}\n")
try:
    out = subprocess.run(["ping", "-c", "20", "-i", "0.2", HOST], capture_output=True, text=True, timeout=90)
    txt = out.stdout + out.stderr
    perd = re.search(r"([\d.]+)% packet loss", txt)
    est = re.search(r"= ([\d.]+)/([\d.]+)/([\d.]+)/([\d.]+) ms", txt)
    ip = re.search(r"PING [^(]*\(([\d.]+)\)", txt)
    R["ping"] = {"paquetes": 20, "perdida_pct": float(perd.group(1)) if perd else None,
                 "min": float(est.group(1)) if est else None, "prom": float(est.group(2)) if est else None,
                 "max": float(est.group(3)) if est else None, "desv": float(est.group(4)) if est else None, "ip": ip.group(1) if ip else None}
    if not est:
        R["ping"]["limitacion"] = "Sin respuestas ICMP (el servidor o la red bloquea ICMP). Se usan las mediciones HTTP; no equivalen al ping."
    print("NET-01 ping (20 paquetes):", R["ping"])
except FileNotFoundError:
    R["ping"] = {"limitacion": "El comando ping no está disponible en este equipo."}
    print("NET-01 ping no disponible")
except subprocess.TimeoutExpired:
    R["ping"] = {"limitacion": "ping excedió 90 s"}
    print("NET-01 ping excedió el tiempo")

# ── NET-02 · latencia HTTP y 10 solicitudes consecutivas ────────
print("\nNET-02 · 10 solicitudes consecutivas a GET /posts (conexión nueva cada vez)")
print(f"{'#':>2} {'HTTP':>4} {'total ms':>9} {'dns':>6} {'tcp':>6} {'tls':>6} {'ttfb':>7} {'bytes':>8}")
tabla = []
for i in range(1, 11):
    r = http("GET", "/posts")
    tabla.append(r)
    t = r["t"]
    print(f"{i:2d} {r['codigo']:4d} {t['total']:9.1f} {t['dns']:6.1f} {t['tcp']:6.1f} {t['tls']:6.1f} {t['ttfb']:7.1f} {r['bytes_cuerpo']:8d}")
tot = [r["t"]["total"] for r in tabla]
R["http_10"] = {"solicitudes": [{"n": i + 1, "codigo": r["codigo"], "ms": round(r["t"]["total"], 1), "bytes": r["bytes_cuerpo"],
                                 "dns": round(r["t"]["dns"], 1), "tcp": round(r["t"]["tcp"], 1), "tls": round(r["t"]["tls"], 1),
                                 "ttfb": round(r["t"]["ttfb"], 1)} for i, r in enumerate(tabla)],
                "total_ms": resumen(tot), "ttfb_ms": resumen([r["t"]["ttfb"] for r in tabla]),
                "exitosas": sum(1 for r in tabla if r["codigo"] == 200), "tam_prom_bytes": round(statistics.mean(r["bytes_cuerpo"] for r in tabla))}
print("   total ms:", R["http_10"]["total_ms"], "· exitosas:", R["http_10"]["exitosas"], "/ 10")

# ── NET-03 · tasa de descarga ───────────────────────────────
print("\nNET-03 · tasa de descarga (3 mediciones de GET /posts)")
R["descarga"] = []
for i in range(3):
    r = http("GET", "/posts")
    seg = r["t"]["total"] / 1000
    mbps = r["bytes_total"] * 8 / seg / 1e6
    mbps_transf = r["bytes_total"] * 8 / max((r["t"]["total"] - r["t"]["ttfb"]) / 1000, 1e-6) / 1e6
    R["descarga"].append({"bytes": r["bytes_total"], "seg": round(seg, 4), "mbps_efectiva": round(mbps, 3), "mbps_solo_transferencia": round(mbps_transf, 2)})
    print(f"   #{i+1}: {r['bytes_total']} B en {seg:.3f} s → {mbps:.3f} Mbps efectivos ({mbps_transf:.1f} Mbps sólo durante la transferencia, tras el primer byte)")

# ── NET-04 · tasa de subida ─────────────────────────────────
# El API no tiene un endpoint público de subida de archivos (la subida real exige
# sesión de la mesa de ayuda). Se envía 1 MB de basura al endpoint JSON de MobileConnect:
# el servidor lee todo el cuerpo, lo rechaza con 400 y no guarda nada. Se mide hasta la respuesta.
print("\nNET-04 · tasa de subida (3 envíos por tamaño de cuerpo inválido; el servidor responde 400 y no guarda nada)")
R["subida"] = []
for kb in (1024, 256, 64):
    carga = b"x" * (kb * 1024)
    for i in range(3):
        r = http("POST", f"/connect/salas/{SALA}/mensajes", cuerpo=carga)
        seg = r["t"]["total"] / 1000
        mbps = r["bytes_enviados"] * 8 / seg / 1e6
        e = {"kb": kb, "codigo": r["codigo"], "bytes": r["bytes_enviados"], "seg": round(seg, 4),
             "mbps_efectiva": round(mbps, 3), "envio_ms": round(r["t"]["envio"], 1), "conexion_cortada": r["cortado"]}
        R["subida"].append(e)
        nota = f" · CONEXIÓN CORTADA ANTES DE TERMINAR EL ENVÍO ({r['cortado']}); el Mbps no es válido" if r["cortado"] else ""
        print(f"   {kb:5d} KB #{i+1}: HTTP {r['codigo']} · {r['bytes_enviados']} B en {seg:.3f} s → {mbps:.3f} Mbps efectivos{nota}")

# ── NET-07 · carga controlada ───────────────────────────────
def escenario(nombre, hacer, concurrentes, total):
    resultados, errores = [], 0
    t0 = time.perf_counter()
    with cf.ThreadPoolExecutor(max_workers=concurrentes) as ex:
        futuros = [ex.submit(hacer) for _ in range(total)]
        for f in futuros:
            try:
                r = f.result()
                resultados.append(r)
            except Exception:
                errores += 1
    dur = time.perf_counter() - t0
    ok = [r for r in resultados if r["codigo"] in (200, 201)]
    fallas = len(resultados) - len(ok) + errores
    ms = [r["t"]["total"] for r in ok] or [0]
    bytes_total = sum(r["bytes_total"] for r in resultados)
    return {"escenario": nombre, "concurrentes": concurrentes, "solicitudes": total, "exitosas": len(ok), "fallidas": fallas,
            "prom_ms": round(statistics.mean(ms), 1), "p95_ms": round(pct(ms, 95), 1), "max_ms": round(max(ms), 1),
            "req_por_s": round(total / dur, 2), "mbps": round(bytes_total * 8 / dur / 1e6, 3), "duracion_s": round(dur, 2)}


print("\nNET-07 · carga controlada (20 solicitudes por escenario)")
cargas = {"lectura GET /posts": lambda: http("GET", "/posts"),
          "escritura POST /connect/…/mensajes": lambda: http("POST", f"/connect/salas/{SALA}/mensajes", {"emisor": "A", "dispositivo": "carga", "texto": "p11"})}
R["carga"] = []
for nombre, fn in cargas.items():
    for c in (1, 5, 10):
        e = escenario(nombre, fn, c, 20)
        R["carga"].append(e)
        print(f"   {nombre:36s} c={c:2d}  ok {e['exitosas']:2d}/{e['solicitudes']}  prom {e['prom_ms']:7.1f} ms  P95 {e['p95_ms']:7.1f} ms  {e['req_por_s']:6.2f} req/s  {e['mbps']:.3f} Mbps")
http("DELETE", f"/connect/salas/{SALA}/mensajes")  # limpieza

d = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "resultados")
os.makedirs(d, exist_ok=True)
with open(os.path.join(d, "red_rendimiento.json"), "w", encoding="utf-8") as f:
    json.dump(R, f, ensure_ascii=False, indent=2)
print("\nGuardado en resultados/red_rendimiento.json")
