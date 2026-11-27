import json
import logging

from fastapi.testclient import TestClient

from app.logging_config import JsonFormatter
from app.main import app


def test_formatter_genera_el_esquema_comun():
    record = logging.LogRecord("cart", logging.WARNING, __file__, 1, "hola %s", ("mundo",), None)
    record.status = 404
    evento = json.loads(JsonFormatter().format(record))
    assert evento["level"] == "warn"
    assert evento["service"] == "carts"
    assert evento["message"] == "hola mundo"
    assert evento["status"] == 404
    assert "timestamp" in evento


def test_formatter_incluye_el_error_cuando_hay_excepcion():
    try:
        raise ValueError("boom")
    except ValueError:
        import sys
        record = logging.LogRecord("cart", logging.ERROR, __file__, 1, "falló", None, sys.exc_info())
    evento = json.loads(JsonFormatter().format(record))
    assert evento["level"] == "error"
    assert "ValueError: boom" in evento["error"]


def test_cada_request_deja_un_log_y_health_no(caplog):
    with caplog.at_level(logging.INFO, logger="cart"), TestClient(app) as client:
        client.get("/health")
        client.get("/ruta-que-no-existe")
    requests = [r for r in caplog.records if r.getMessage() == "request"]
    assert len(requests) == 1
    assert requests[0].status == 404
    assert requests[0].levelno == logging.WARNING
