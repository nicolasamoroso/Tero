import { NextFunction, Request, Response } from 'express';

type Nivel = 'debug' | 'info' | 'warn' | 'error';

const SERVICIO = 'admin';
const SIN_LOG = new Set(['/health', '/metrics']);

// Una línea JSON por evento, con el mismo esquema que el resto de los servicios.
export function log(level: Nivel, message: string, fields: Record<string, unknown> = {}): void {
  const evento = { timestamp: new Date().toISOString(), level, service: SERVICIO, message, ...fields };
  process.stdout.write(JSON.stringify(evento) + '\n');
}

function nivelPorStatus(status: number): Nivel {
  if (status >= 500) return 'error';
  if (status >= 400) return 'warn';
  return 'info';
}

// Loguea cada request al terminar (sin query string) y se salta /health y /metrics.
export function requestLogger(req: Request, res: Response, next: NextFunction): void {
  const inicio = process.hrtime.bigint();
  res.on('finish', () => {
    if (SIN_LOG.has(req.path)) return;
    log(nivelPorStatus(res.statusCode), 'request', {
      method: req.method,
      path: req.path,
      status: res.statusCode,
      duration_ms: Number(process.hrtime.bigint() - inicio) / 1e6,
      remote_ip: req.ip,
    });
  });
  next();
}
