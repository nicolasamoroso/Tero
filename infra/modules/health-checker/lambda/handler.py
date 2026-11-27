"""Health-checker de Tero.

Cada 5 minutos (regla de EventBridge) llama al /health de cada servicio a través del ALB
interno y publica la métrica Tero/Availability en CloudWatch.

La métrica se publica con el formato EMF (Embedded Metric Format): una línea JSON en el log
que CloudWatch convierte en métrica. No hace falta llamar a la API de CloudWatch, que desde
las subnets privadas no se alcanza porque no hay NAT Gateway (ADR 0001).
"""

import http.client
import json
import time
from urllib.parse import urlsplit

NAMESPACE = "Tero/Availability"
TIMEOUT_SECONDS = 5


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
    # EventBridge manda la lista de servicios en el evento: {"targets": {"catalog": "http://..."}}
    targets = event["targets"]

    results = {}
    for service, url in sorted(targets.items()):
        healthy, detail = check(url)
        results[service] = healthy
        # Una métrica por servicio (1 = sano, 0 = caído), para ver cuál falló
        print(json.dumps(emf({"Healthy": (int(healthy), "Count")}, {"Service": service})))
        print(json.dumps({"service": service, "healthy": healthy, "detail": detail}))

    # La métrica general: el porcentaje de servicios sanos. Es la que mira la alarma
    availability = 100 * sum(results.values()) / len(results)
    print(json.dumps(emf({"Availability": (availability, "Percent")})))

    return {"availability": availability, "services": results}
