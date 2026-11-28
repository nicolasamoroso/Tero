"""Health-checker de Tero.

Llama al /health de cada servicio a través del ALB interno. La invocan dos cosas:

- La regla de EventBridge, cada 5 minutos: publica la métrica Tero/Availability en CloudWatch.
- La HTTP API (GET /status): responde el estado de cada servicio, sin publicar métricas, así
  las consultas a la API no cambian lo que mira la alarma.

La métrica se publica con el formato EMF (Embedded Metric Format): una línea JSON en el log
que CloudWatch convierte en métrica. No hace falta llamar a la API de CloudWatch, que desde
las subnets privadas no se alcanza porque no hay NAT Gateway (ADR 0001).

La lista de servicios viene en targets.json, dentro del mismo zip (la arma Terraform).
"""

import http.client
import json
import os
import time
from urllib.parse import urlsplit

NAMESPACE = "Tero/Availability"
TIMEOUT_SECONDS = 5
TARGETS_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "targets.json")


def load_targets():
    with open(TARGETS_FILE, encoding="utf-8") as targets:
        return json.load(targets)


def check(url):
    """Devuelve (sano, detalle). Sano = el /health respondió 200 antes del timeout."""
    parts = urlsplit(url)
    conn = http.client.HTTPConnection(parts.hostname, parts.port or 80, timeout=TIMEOUT_SECONDS)
    try:
        conn.request("GET", parts.path or "/")
        status = conn.getresponse().status
        return status == 200, f"HTTP {status}"
    except (OSError, http.client.HTTPException) as error:
        return False, type(error).__name__
    finally:
        conn.close()


def emf(metrics, dimensions=None):
    """Arma una línea EMF con las métricas dadas y, si hay, sus dimensiones."""
    dimensions = dimensions or {}
    return {
        "_aws": {
            "Timestamp": int(time.time() * 1000),
            "CloudWatchMetrics": [
                {
                    "Namespace": NAMESPACE,
                    "Dimensions": [list(dimensions)],
                    "Metrics": [{"Name": name, "Unit": unit} for name, (_, unit) in metrics.items()],
                }
            ],
        },
        **dimensions,
        **{name: value for name, (value, _) in metrics.items()},
    }


def handler(event, context):
    # La HTTP API manda requestContext; EventBridge, no
    from_api = "requestContext" in (event or {})

    results = {}
    for service, url in sorted(load_targets().items()):
        healthy, detail = check(url)
        results[service] = healthy
        print(json.dumps({"service": service, "healthy": healthy, "detail": detail}))
        if not from_api:
            # Una métrica por servicio (1 = sano, 0 = caído), para ver cuál falló
            print(json.dumps(emf({"Healthy": (int(healthy), "Count")}, {"Service": service})))

    availability = 100 * sum(results.values()) / len(results)
    status = {"availability": availability, "services": results}

    if from_api:
        # 200 si están todos sanos, 503 si alguno no: sirve para un monitor externo
        return {
            "statusCode": 200 if availability == 100 else 503,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps(status),
        }

    # La métrica general: el porcentaje de servicios sanos. Es la que mira la alarma
    print(json.dumps(emf({"Availability": (availability, "Percent")})))
    return status
