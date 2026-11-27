import { LoggerService } from '@nestjs/common';
import { log } from './logger';

const texto = (mensaje: unknown): string => (typeof mensaje === 'string' ? mensaje : JSON.stringify(mensaje));

const contexto = (params: unknown[]): string | undefined => {
  const ultimo = params[params.length - 1];
  return typeof ultimo === 'string' ? ultimo : undefined;
};

// Reemplaza al logger de texto de Nest: los mensajes del framework también salen en JSON.
export class JsonLogger implements LoggerService {
  log(message: unknown, ...params: unknown[]): void {
    log('info', texto(message), { context: contexto(params) });
  }

  warn(message: unknown, ...params: unknown[]): void {
    log('warn', texto(message), { context: contexto(params) });
  }

  debug(message: unknown, ...params: unknown[]): void {
    log('debug', texto(message), { context: contexto(params) });
  }

  verbose(message: unknown, ...params: unknown[]): void {
    log('debug', texto(message), { context: contexto(params) });
  }

  error(message: unknown, ...params: unknown[]): void {
    log('error', texto(message), { context: contexto(params), stack: params.length > 1 ? params[0] : undefined });
  }
}
