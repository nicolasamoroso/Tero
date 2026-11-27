import { JsonLogger } from './json-logger';
import { log } from './logger';

describe('logger JSON', () => {
  let salida: string[];

  beforeEach(() => {
    salida = [];
    jest.spyOn(process.stdout, 'write').mockImplementation((texto: string | Uint8Array) => {
      salida.push(String(texto));
      return true;
    });
  });

  afterEach(() => jest.restoreAllMocks());

  it('escribe una línea JSON con el esquema común', () => {
    log('warn', 'hola', { status: 404 });
    const evento = JSON.parse(salida[0]);
    expect(evento).toMatchObject({ level: 'warn', service: 'checkout', message: 'hola', status: 404 });
    expect(typeof evento.timestamp).toBe('string');
  });

  it('JsonLogger traduce los niveles y el contexto de Nest', () => {
    const logger = new JsonLogger();
    logger.log('arranque', 'NestApplication');
    logger.warn('ojo');
    logger.error('falló', 'el-stack', 'Contexto');
    const eventos = salida.map((linea) => JSON.parse(linea));
    expect(eventos.map((e) => e.level)).toEqual(['info', 'warn', 'error']);
    expect(eventos[0].context).toBe('NestApplication');
    expect(eventos[2]).toMatchObject({ context: 'Contexto', stack: 'el-stack' });
  });
});
