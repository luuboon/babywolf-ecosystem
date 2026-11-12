#!/usr/bin/env python3
"""Práctica 12 · Fase 3 — Prueba de estrés reproducible (sólo biblioteca estándar).

Lanza N hilos concurrentes (conexión persistente cada uno) contra un endpoint
durante DURACIÓN segundos por nivel y calcula: solicitudes por segundo (RPS),
promedio, P90, P95 (rango más cercano), máximo, % de errores, códigos HTTP,
bytes por respuesta y —si se da el PID del servidor— CPU y RAM del servidor.

Uso:
  carga.py --base http://127.0.0.1:8081/api --ruta /posts --niveles 1,5,10,25 --duracion 15
  carga.py ... --metodo POST --ruta /admin/posts --jwt-secret S --jwt-sub UUID --pid 1234
Salida: tabla en pantalla y, con --json, un archivo JSON.
"""
import argparse, base64, hashlib, hmac, http.client, json, math, os, statistics, subprocess, sys, threading, time, urllib.parse, uuid, datetime, platform

def b64(b): return base64.urlsafe_b64encode(b).rstrip(b"=").decode()

def jwt_hs256(secret, sub):
    h = b64(json.dumps({"alg": "HS256", "typ": "JWT"}).encode())
    p = b64(json.dumps({"sub": sub, "email": "admin@bw.test", "exp": int(time.time()) + 3600}).encode())
    s = b64(hmac.new(secret.encode(), f"{h}.{p}".encode(), hashlib.sha256).digest())
    return f"{h}.{p}.{s}"

def percentil(xs, p):
    if not xs: return float("nan")
    xs = sorted(xs); k = max(1, math.ceil(p / 100 * len(xs)))
    return xs[k - 1]

def cpu_seg(pid):
    """CPU acumulada del proceso en segundos (ps cputime M:SS.cc o H:MM:SS)."""
    try:
        t = subprocess.run(["ps", "-o", "cputime=", "-p", str(pid)], capture_output=True, text=True).stdout.strip()
        partes = [float(x) for x in t.split(":")]
        seg = 0.0
        for x in partes: seg = seg * 60 + x
        return seg
    except Exception:
        return None

def rss_mb(pid):
    try:
        k = subprocess.run(["ps", "-o", "rss=", "-p", str(pid)], capture_output=True, text=True).stdout.strip()
        return int(k) / 1024
    except Exception:
        return None

def nivel(args, u, concurrencia, cabeceras, cuerpo_fn):
    lat, codigos, tams, errores = [], {}, [], [0]
    cerrojo = threading.Lock()
    fin = time.perf_counter() + args.duracion
    ram = []
    parar = threading.Event()

    def muestrear():
        while not parar.is_set():
            r = rss_mb(args.pid) if args.pid else None
            if r is not None: ram.append(r)
            parar.wait(0.5)

    def hilo():
        cx = None
        while time.perf_counter() < fin:
            try:
                if cx is None:
                    cx = (http.client.HTTPSConnection if u.scheme == "https" else http.client.HTTPConnection)(u.hostname, u.port, timeout=args.timeout)
                cuerpo = cuerpo_fn() if cuerpo_fn else None
                t0 = time.perf_counter()
                cx.request(args.metodo, u.path + args.ruta + (("?" + args.consulta) if args.consulta else ""), body=cuerpo, headers=cabeceras)
                r = cx.getresponse(); datos = r.read()
                dt = (time.perf_counter() - t0) * 1000
                with cerrojo:
                    lat.append(dt); tams.append(len(datos))
                    codigos[r.status] = codigos.get(r.status, 0) + 1
                    if r.status >= 400: errores[0] += 1
                if r.getheader("Connection", "").lower() == "close": cx.close(); cx = None
            except Exception as e:
                with cerrojo:
                    errores[0] += 1; codigos["excepción:" + type(e).__name__] = codigos.get("excepción:" + type(e).__name__, 0) + 1
                try: cx and cx.close()
                except Exception: pass
                cx = None

    cpu0 = cpu_seg(args.pid) if args.pid else None
    t_ini = time.perf_counter()
    m = threading.Thread(target=muestrear, daemon=True); m.start()
    hs = [threading.Thread(target=hilo) for _ in range(concurrencia)]
    [h.start() for h in hs]; [h.join() for h in hs]
    dur = time.perf_counter() - t_ini
    parar.set(); m.join(timeout=1)
    cpu1 = cpu_seg(args.pid) if args.pid else None
    n = len(lat) + sum(v for k, v in codigos.items() if isinstance(k, str))
    res = {
        "concurrencia": concurrencia, "duracion_s": round(dur, 2), "solicitudes": n,
        "rps": round(len(lat) / dur, 1) if dur else 0,
        "prom_ms": round(statistics.mean(lat), 1) if lat else None,
        "p50_ms": round(percentil(lat, 50), 1) if lat else None,
        "p90_ms": round(percentil(lat, 90), 1) if lat else None,
        "p95_ms": round(percentil(lat, 95), 1) if lat else None,
        "max_ms": round(max(lat), 1) if lat else None,
        "errores": errores[0], "errores_pct": round(100 * errores[0] / n, 2) if n else None,
        "codigos": {str(k): v for k, v in codigos.items()},
        "bytes_resp_prom": round(statistics.mean(tams)) if tams else None,
        "srv_cpu_prom_pct": round(100 * (cpu1 - cpu0) / dur, 1) if cpu0 is not None and cpu1 is not None and dur else None,
        "srv_ram_max_mb": round(max(ram), 1) if ram else None,
    }
    return res

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", required=True); ap.add_argument("--ruta", required=True)
    ap.add_argument("--consulta", default=""); ap.add_argument("--metodo", default="GET")
    ap.add_argument("--niveles", default="1,5,10"); ap.add_argument("--duracion", type=float, default=10)
    ap.add_argument("--timeout", type=float, default=30); ap.add_argument("--pid", type=int)
    ap.add_argument("--jwt-secret"); ap.add_argument("--jwt-sub"); ap.add_argument("--etiqueta", default="")
    ap.add_argument("--json"); ap.add_argument("--calentamiento", type=int, default=3)
    args = ap.parse_args()
    u = urllib.parse.urlparse(args.base.rstrip("/"))
    args.ruta = args.ruta if args.ruta.startswith("/") else "/" + args.ruta
    args.base_path = u.path
    cab = {"Accept": "application/json", "User-Agent": "bw-p12-carga"}
    cuerpo_fn = None
    if args.jwt_secret: cab["Authorization"] = "Bearer " + jwt_hs256(args.jwt_secret, args.jwt_sub)
    if args.metodo == "POST":
        cab["Content-Type"] = "application/json"
        def cuerpo_fn():
            s = uuid.uuid4().hex
            return json.dumps({"title": "Carga " + s[:8], "slug": "carga-" + s, "content": "Contenido de la prueba de carga. " * 15, "category": "general", "published": True})
    # calentamiento (no se cuenta)
    cx = (http.client.HTTPSConnection if u.scheme == "https" else http.client.HTTPConnection)(u.hostname, u.port, timeout=args.timeout)
    for _ in range(args.calentamiento):
        try:
            cx.request(args.metodo, u.path + args.ruta + (("?" + args.consulta) if args.consulta else ""), body=cuerpo_fn() if cuerpo_fn else None, headers=cab); cx.getresponse().read()
        except Exception: pass
    cx.close()
    print(f"# Carga {args.etiqueta} — {args.metodo} {args.base}{args.ruta}{'?' + args.consulta if args.consulta else ''} — {datetime.datetime.now().astimezone().isoformat(timespec='seconds')}")
    print(f"# Cliente: {platform.platform()} · Python {platform.python_version()} · {args.duracion:g} s por nivel · hilos con conexión persistente")
    cols = ["concurrencia", "solicitudes", "rps", "prom_ms", "p90_ms", "p95_ms", "max_ms", "errores_pct", "bytes_resp_prom", "srv_cpu_prom_pct", "srv_ram_max_mb"]
    print(" ".join(f"{c:>12}" for c in cols))
    todos = []
    for c in [int(x) for x in args.niveles.split(",")]:
        r = nivel(args, u, c, cab, cuerpo_fn); todos.append(r)
        print(" ".join(f"{str(r[k]):>12}" for k in cols)); sys.stdout.flush()
        print(f"{'':>12} códigos: {r['codigos']}")
        time.sleep(1)
    if args.json:
        json.dump({"etiqueta": args.etiqueta, "metodo": args.metodo, "url": args.base + args.ruta, "consulta": args.consulta, "fecha": datetime.datetime.now().astimezone().isoformat(),
                   "cliente": platform.platform(), "duracion_por_nivel_s": args.duracion, "niveles": todos}, open(args.json, "w"), indent=1, ensure_ascii=False)

if __name__ == "__main__":
    main()
