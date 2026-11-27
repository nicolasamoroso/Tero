import { Request, Response } from 'express';
import { JsonLogger } from './json-logger';
import { log, requestLogger } from './logger';

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

describe('requestLogger', () => {
  let salida: string[];

  beforeEach(() => {
    salida = [];
    jest.spyOn(process.stdout, 'write').mockImplementation((texto: string | Uint8Array) => {
      salida.push(String(texto));
      return true;
    });
  });

  afterEach(() => jest.restoreAllMocks());

  const pedir = (path: string, statusCode: number) => {
    let alTerminar: () => void = () => undefined;
    const res = {
      statusCode,
      on: (_evento: string, fn: () => void) => {
        alTerminar = fn;
      },
    } as unknown as Response;
    const next = jest.fn();
    requestLogger({ method: 'GET', path, ip: '1.2.3.4' } as unknown as Request, res, next);
    alTerminar();
    expect(next).toHaveBeenCalled();
  };

  it('deja una línea por request con el nivel según el status', () => {
    pedir('/nada', 404);
    pedir('/roto', 500);
    pedir('/ok', 200);
    const eventos = salida.map((linea) => JSON.parse(linea));
    expect(eventos.map((e) => e.level)).toEqual(['warn', 'error', 'info']);
    expect(eventos[0]).toMatchObject({ message: 'request', method: 'GET', path: '/nada', status: 404 });
  });

  it('no loguea /health', () => {
    pedir('/health', 200);
    expect(salida).toHaveLength(0);
  });
});
