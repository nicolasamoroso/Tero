import pytest
from fastapi.testclient import TestClient

from app.main import app

ITEM = {"itemId": "prod-1", "quantity": 2, "unitPrice": 100}


@pytest.fixture
def client():
    # El "with" dispara el startup de la app: cada test arranca con un carrito en memoria vacío
    with TestClient(app) as c:
        yield c


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json() == {"status": "UP"}


def test_carrito_nuevo_esta_vacio(client):
    r = client.get("/carts/cliente-1")
    assert r.status_code == 200
    assert r.json() == {"customerId": "cliente-1", "items": []}


def test_agregar_y_listar_items(client):
    r = client.post("/carts/cliente-1/items", json=ITEM)
    assert r.status_code == 201
    assert r.json() == ITEM

    r = client.get("/carts/cliente-1/items")
    assert r.status_code == 200
    assert r.json() == [ITEM]


def test_item_inexistente_da_404(client):
    r = client.get("/carts/cliente-1/items/no-existe")
    assert r.status_code == 404


def test_actualizar_item(client):
    client.post("/carts/cliente-1/items", json=ITEM)

    r = client.patch("/carts/cliente-1/items", json={**ITEM, "quantity": 5})
    assert r.status_code == 202
    assert client.get("/carts/cliente-1/items/prod-1").json()["quantity"] == 5


def test_actualizar_item_inexistente_da_404(client):
    r = client.patch("/carts/cliente-1/items", json=ITEM)
    assert r.status_code == 404


def test_borrar_item(client):
    client.post("/carts/cliente-1/items", json=ITEM)

    r = client.delete("/carts/cliente-1/items/prod-1")
    assert r.status_code == 202
    assert client.get("/carts/cliente-1/items").json() == []


def test_borrar_carrito(client):
    client.post("/carts/cliente-1/items", json=ITEM)

    r = client.delete("/carts/cliente-1")
    assert r.status_code == 202
    assert client.get("/carts/cliente-1").json()["items"] == []


def test_merge_pasa_los_items_de_la_sesion_al_cliente(client):
    client.post("/carts/sesion-anonima/items", json=ITEM)

    r = client.get("/carts/cliente-1/merge", params={"sessionId": "sesion-anonima"})
    assert r.status_code == 202
    assert client.get("/carts/cliente-1/items").json() == [ITEM]
    assert client.get("/carts/sesion-anonima/items").json() == []


def test_item_invalido_da_422(client):
    r = client.post("/carts/cliente-1/items", json={"itemId": "prod-1"})
    assert r.status_code == 422
