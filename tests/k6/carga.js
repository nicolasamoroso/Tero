// Prueba de carga de Tero con k6, contra el ALB público de un ambiente.
//
// Cada usuario virtual hace lo que haría un cliente: mira el catálogo, abre un producto, lo
// agrega al carrito y mira el carrito. Uno de cada cinco además completa la compra (checkout y
// orden). Así la carga llega a los 5 servicios: ui, catalog, carts, checkout y orders.
//
// Uso (ver README, sección Prueba de carga):
//   docker run --rm -i -e BASE_URL=http://<alb> grafana/k6:1.4.2 run - < tests/k6/carga.js

import http from 'k6/http';
import { check, group, sleep } from 'k6';

const BASE_URL = __ENV.BASE_URL;
if (!BASE_URL) {
  throw new Error('Falta BASE_URL, por ejemplo -e BASE_URL=http://tero-dev-alb-123.us-east-1.elb.amazonaws.com');
}

export const options = {
  // Sube a 10 usuarios en 30 s, se queda 2 minutos y baja. Es poca carga a propósito: cada task
  // tiene 0,25 vCPU en dev y el presupuesto de Academy es compartido.
  stages: [
    { duration: '30s', target: 10 },
    { duration: '2m', target: 10 },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    // Los mismos criterios que las alarmas de DEV-41: si se pasan acá, en el ambiente saltaría la alarma
    http_req_duration: ['p(95)<1000'],
    http_req_failed: ['rate<0.01'],
    checks: ['rate>0.99'],
    // Por paso, para ver cuál se degrada primero
    'http_req_duration{paso:catalogo}': ['p(95)<1000'],
    'http_req_duration{paso:carrito}': ['p(95)<1000'],
    'http_req_duration{paso:compra}': ['p(95)<1500'],
  },
};

const json = { headers: { 'Content-Type': 'application/json' } };

// Identifica la corrida, así un cliente no choca con datos que dejó una corrida anterior
export function setup() {
  return { run: Date.now().toString(36) };
}

export default function (data) {
  const customer = `k6-${data.run}-${__VU}-${__ITER}`;
  let product;

  group('catalogo', () => {
    const res = http.get(`${BASE_URL}/api/catalog/products`, { tags: { paso: 'catalogo' } });
    const ok = check(res, {
      'catálogo responde 200': (r) => r.status === 200,
      // Solo parsea si respondió 200: un 502 trae HTML y r.json() cortaría la iteración
      'catálogo trae productos': (r) => r.status === 200 && r.json().length > 0,
    });
    if (ok) {
      const products = res.json();
      product = products[Math.floor(Math.random() * products.length)];
      const one = http.get(`${BASE_URL}/api/catalog/products/${product.id}`, { tags: { paso: 'catalogo' } });
      check(one, { 'producto responde 200': (r) => r.status === 200 });
    }
  });
  if (!product) {
    return;
  }
  sleep(1);

  group('carrito', () => {
    const body = JSON.stringify({ itemId: product.id, quantity: 1, unitPrice: product.price });
    const add = http.post(`${BASE_URL}/api/carts/${customer}/items`, body, { ...json, tags: { paso: 'carrito' } });
    check(add, { 'agregar al carrito responde 2xx': (r) => r.status >= 200 && r.status < 300 });

    const cart = http.get(`${BASE_URL}/api/carts/${customer}`, { tags: { paso: 'carrito' } });
    check(cart, { 'ver el carrito responde 200': (r) => r.status === 200 });
  });
  sleep(1);

  // Uno de cada cinco clientes compra
  if (Math.random() < 0.2) {
    group('compra', () => {
      const checkout = JSON.stringify({
        items: [{ id: product.id, name: product.name, quantity: 1, price: product.price }],
        shippingAddress: {
          firstName: 'Carga',
          lastName: 'k6',
          email: 'k6@example.com',
          address1: 'Calle 1234',
          city: 'Montevideo',
          state: 'Montevideo',
          zip: '11100',
        },
      });
      const update = http.post(`${BASE_URL}/api/checkout/${customer}/update`, checkout, { ...json, tags: { paso: 'compra' } });
      check(update, { 'cargar el checkout responde 2xx': (r) => r.status >= 200 && r.status < 300 });

      const submit = http.post(`${BASE_URL}/api/checkout/${customer}/submit`, null, { ...json, tags: { paso: 'compra' } });
      check(submit, { 'confirmar la compra responde 2xx': (r) => r.status >= 200 && r.status < 300 });
    });
  }

  // Deja el carrito vacío para no acumular datos de prueba
  http.del(`${BASE_URL}/api/carts/${customer}`, null, { tags: { paso: 'carrito' } });
  sleep(1);
}
