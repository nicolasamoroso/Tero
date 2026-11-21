import { Test } from '@nestjs/testing';
import { CheckoutService } from './checkout.service';
import { CheckoutRequest } from './models/CheckoutRequest';
import { MockOrdersService } from './orders';
import { InMemoryCheckoutRepository } from './repositories';
import { MockShippingService } from './shipping';

// Pedido de ejemplo: 2 x 100 + 1 x 50 = subtotal 250
const pedido = (conDireccion = true): CheckoutRequest =>
  ({
    items: [
      { id: 'prod-1', name: 'Reloj', quantity: 2, price: 100 },
      { id: 'prod-2', name: 'Medias', quantity: 1, price: 50 },
    ],
    shippingAddress: conDireccion
      ? {
          firstName: 'Ana',
          lastName: 'Test',
          address1: 'Calle 1',
          city: 'Montevideo',
          state: 'MVD',
          zip: '11000',
          email: 'ana@example.com',
        }
      : undefined,
    deliveryOptionToken: 'priority-mail',
  }) as CheckoutRequest;

describe('CheckoutService', () => {
  let service: CheckoutService;

  // Antes de cada test arma el módulo de Nest con las implementaciones en memoria y mock
  // (las mismas que usa la app cuando no hay Redis ni servicio de orders configurados)
  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [
        CheckoutService,
        { provide: 'CheckoutRepository', useValue: new InMemoryCheckoutRepository() },
        { provide: 'OrdersService', useValue: new MockOrdersService() },
        { provide: 'ShippingService', useValue: new MockShippingService('') },
      ],
    }).compile();

    service = module.get(CheckoutService);
  });

  it('calcula el total por item, el subtotal, el envío y el impuesto', async () => {
    const checkout = await service.update('cliente-1', pedido());

    expect(checkout.items.map((i) => i.totalCost)).toEqual([200, 50]);
    expect(checkout.subtotal).toBe(250);
    expect(checkout.shipping).toBe(10); // tarifa de priority-mail del MockShippingService
    expect(checkout.tax).toBe(5);
    expect(checkout.total).toBe(265);
  });

  it('sin dirección no cobra envío ni impuesto', async () => {
    const checkout = await service.update('cliente-1', pedido(false));

    expect(checkout.shippingRates).toBeNull();
    expect(checkout.total).toBe(250);
  });

  it('get devuelve null si el cliente no tiene checkout', async () => {
    expect(await service.get('no-existe')).toBeNull();
  });

  it('get devuelve el checkout guardado', async () => {
    await service.update('cliente-1', pedido());

    const checkout = await service.get('cliente-1');
    expect(checkout.subtotal).toBe(250);
    expect(checkout.items).toHaveLength(2);
  });

  it('submit crea la orden y borra el checkout', async () => {
    await service.update('cliente-1', pedido());

    const enviado = await service.submit('cliente-1');

    expect(enviado.orderId).toBeDefined();
    expect(enviado.email).toBe('ana@example.com');
    expect(enviado.total).toBe(265);
    expect(await service.get('cliente-1')).toBeNull();
  });

  it('submit sin checkout falla', async () => {
    await expect(service.submit('no-existe')).rejects.toThrow('Checkout not found');
  });
});
