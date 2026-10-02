import { describe, expect, it, vi } from 'vitest';
import { ApiError, COMMANDS, createAutenticacionJwtYCreacionDePedidosEnRails7ApiClient } from './autenticacion-jwt-y-creacion-de-pedidos-en-rails7-api-client';

function fakeFetch(status: number, body: unknown) {
  return vi.fn(async (_url: RequestInfo | URL, _init?: RequestInit) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } }));
}

describe('AutenticacionJwtYCreacionDePedidosEnRails7Api API client', () => {
  it('exposes one method per domain command', () => {
    expect(COMMANDS).toEqual(['process_autenticacion_jwt_y_creacion_de_pedidos_en_rails7_api']);
  });

  it('posts the command with tenant and idempotency headers', async () => {
    const fetch = fakeFetch(201, { type: 'ProcessAutenticacionJwtYCreacionDePedidosEnRails7ApiCompleted', aggregateId: 'agg-1', version: 1 });
    const client = createAutenticacionJwtYCreacionDePedidosEnRails7ApiClient({ baseUrl: 'https://api.test/', tenantId: 'acme', fetch });

    const result = await client.processAutenticacionJwtYCreacionDePedidosEnRails7Api('agg-1', { amount: 100 }, { idempotencyKey: 'key-1' });

    expect(result).toEqual({ type: 'ProcessAutenticacionJwtYCreacionDePedidosEnRails7ApiCompleted', aggregateId: 'agg-1', version: 1 });
    const [url, init] = fetch.mock.calls[0];
    expect(url).toBe('https://api.test/api/v1/autenticacion-jwt-y-creacion-de-pedidos-en-rails7-api/agg-1/process_autenticacion_jwt_y_creacion_de_pedidos_en_rails7_api');
    expect(init?.method).toBe('POST');
    expect((init?.headers as Record<string, string>)['X-Tenant-Id']).toBe('acme');
    expect((init?.headers as Record<string, string>)['X-Idempotency-Key']).toBe('key-1');
    expect(JSON.parse(String(init?.body))).toEqual({ amount: 100 });
  });

  it('raises ApiError with the server detail on failure', async () => {
    const client = createAutenticacionJwtYCreacionDePedidosEnRails7ApiClient({ fetch: fakeFetch(422, { detail: 'Command id is required' }) });
    await expect(client.execute('agg-1', 'process_autenticacion_jwt_y_creacion_de_pedidos_en_rails7_api')).rejects.toEqual(new ApiError(422, 'Command id is required'));
  });
});
