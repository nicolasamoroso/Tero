from app.models import Item
from app.service import InMemoryCartService


def test_merge_no_pisa_un_item_que_el_cliente_ya_tenia():
    svc = InMemoryCartService()
    svc.add_item("cliente-1", Item(itemId="prod-1", quantity=1, unitPrice=100))
    svc.add_item("sesion", Item(itemId="prod-1", quantity=9, unitPrice=100))
    svc.add_item("sesion", Item(itemId="prod-2", quantity=1, unitPrice=50))

    svc.merge("cliente-1", "sesion")

    items = {i.itemId: i.quantity for i in svc.get_items("cliente-1")}
    assert items == {"prod-1": 1, "prod-2": 1}


def test_borrar_un_item_que_no_existe_no_falla():
    svc = InMemoryCartService()
    svc.delete_item("cliente-1", "no-existe")
    assert svc.get_items("cliente-1") == []
