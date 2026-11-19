# Prácticas 13 y 14 — Automatización de pruebas y validación continua (Flutter)

App: `phone_app` (Flutter 3.47.9). Pipeline: `.github/workflows/flutter-ci.yml` (en cada push y pull request: `flutter pub get`, `flutter analyze`, `flutter test`).

## Componentes críticos elegidos
1. **Función crítica del móvil:** inicio de sesión y registro (`lib/core/validacion.dart`: `Validar`, `LimiteIntentos`).
2. **Servicio/endpoint:** `GET /api/posts` (`BlogApi`) y publicación de comentarios (`ComentariosApi`).
3. **Persistencia:** noticias guardadas en SQLite (`GuardadaDao`, `Guardadas`).

Riesgos previos que previenen: D-06 (JSON roto con 200 → FormatException), RES-07 (reintento que duplica un comentario), límite de contraseña de 72 caracteres.

## Matriz de automatización
| ID | Tipo | Archivo | Pruebas | Estado |
|---|---|---|---|---|
| AUT-01 | Unitarias | `test/automatizacion/aut_unitarias_test.dart` | 5 (validación de correo, contraseña, apodo) | Aprobado |
| AUT-02 | Unitarias | idem | 3 (comentarios y notas) | Aprobado |
| AUT-03 | Unitarias | idem | 4 (LimiteIntentos y Post.fromJson) | Aprobado |
| AUT-04 | Integración | `aut_integracion_test.dart` | 7 (BlogApi ↔ servidor HTTP local real) | Aprobado |
| AUT-05 | Integración | idem | 5 (ComentariosApi ↔ PostgREST simulado) | Aprobado |
| AUT-06 | Persistencia | `aut_persistencia_test.dart` | 5 (SQLite real, archivo en disco) | Aprobado |
| AUT-07 | CI | `.github/workflows/flutter-ci.yml` | corre solo en push/PR | Aprobado (run 44427637360) |
| AUT-08 | CI | idem | un push que rompe una regla hace fallar el flujo | Aprobado (run 44428003533) |

## Evidencia (`evidencia/`)
- Run 44426604567 (push 90fc724): FALLÓ en análisis — Flutter 3.50.0 (canal stable) marcó 22 avisos por `material.dart` obsoleto + 1 import innecesario mío.
- Run 44426931234 (push 4685483): FALLÓ — con Flutter 3.47.9 fijado, 1 aviso (`dart:ui` innecesario en `integration_test`).
- Run 44427637360 (push cab0196): **ÉXITO** — análisis sin avisos, 169 pruebas aprobadas, 0 fallidas, 40 s de pruebas, 2 min 1 s el job.
- Run 44428003533 (rama de demostración, límite de contraseña cambiado a propósito de 72 a 100): FALLÓ como se esperaba — 166 aprobadas, 3 fallidas (AUT-01c y dos de las prácticas 5 y 11).
