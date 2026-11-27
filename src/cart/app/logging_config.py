import json
import logging
import sys
from datetime import datetime, timezone

SERVICE = "carts"
CAMPOS_HTTP = ("method", "path", "status", "duration_ms", "remote_ip")
NIVELES = {"warning": "warn", "critical": "error"}


class JsonFormatter(logging.Formatter):
    """Una línea JSON por evento, con el esquema común de los servicios."""

    def format(self, record: logging.LogRecord) -> str:
        nivel = record.levelname.lower()
        evento = {
            "timestamp": datetime.fromtimestamp(record.created, timezone.utc).isoformat(timespec="milliseconds"),
            "level": NIVELES.get(nivel, nivel),
            "service": SERVICE,
            "message": record.getMessage(),
        }
        for campo in CAMPOS_HTTP:
            if hasattr(record, campo):
                evento[campo] = getattr(record, campo)
        if record.exc_info:
            evento["error"] = self.formatException(record.exc_info)
        return json.dumps(evento, ensure_ascii=False)


def setup_logging() -> None:
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonFormatter())
    root = logging.getLogger()
    root.handlers = [handler]
    root.setLevel(logging.INFO)
    # Los logs de uvicorn pasan por el handler JSON de root
    for nombre in ("uvicorn", "uvicorn.error"):
        logging.getLogger(nombre).handlers = []
        logging.getLogger(nombre).propagate = True
    # Los requests los loguea el middleware de app.main con el esquema común
    acceso = logging.getLogger("uvicorn.access")
    acceso.handlers = []
    acceso.propagate = False
