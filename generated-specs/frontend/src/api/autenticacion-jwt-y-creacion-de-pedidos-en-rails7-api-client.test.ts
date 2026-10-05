import { describe, expect, it, vi } from 'vitest';
import { ApiError, COMMANDS, createAutenticacionJwtYCreacionDePedidosEnRails7ApiClient, newTraceparent } from './autenticacion-jwt-y-creacion-de-pedidos-en-rails7-api-client';

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

  it('sends a W3C traceparent that starts a new trace per request', async () => {
    const fetch = fakeFetch(201, { type: 'ProcessAutenticacionJwtYCreacionDePedidosEnRails7ApiCompleted', aggregateId: 'agg-1', version: 1 });
    const client = createAutenticacionJwtYCreacionDePedidosEnRails7ApiClient({ fetch });

    await client.execute('agg-1', 'process_autenticacion_jwt_y_creacion_de_pedidos_en_rails7_api');
    await client.execute('agg-1', 'process_autenticacion_jwt_y_creacion_de_pedidos_en_rails7_api');

    const sent = fetch.mock.calls.map(([, init]) => (init?.headers as Record<string, string>).traceparent);
    for (const traceparent of sent) expect(traceparent).toMatch(/^00-[0-9a-f]{32}-[0-9a-f]{16}-01$/);
    expect(sent[0]).not.toBe(sent[1]);
    expect(newTraceparent()).toMatch(/^00-[0-9a-f]{32}-[0-9a-f]{16}-01$/);
  });

  it('propagates the caller trace context or none when disabled', async () => {
    const traced = fakeFetch(201, {});
    const parent = '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01';
    await createAutenticacionJwtYCreacionDePedidosEnRails7ApiClient({ fetch: traced, traceparent: () => parent }).execute('agg-1', 'process_autenticacion_jwt_y_creacion_de_pedidos_en_rails7_api');
    expect((traced.mock.calls[0][1]?.headers as Record<string, string>).traceparent).toBe(parent);

    const untraced = fakeFetch(201, {});
    await createAutenticacionJwtYCreacionDePedidosEnRails7ApiClient({ fetch: untraced, traceparent: false }).execute('agg-1', 'process_autenticacion_jwt_y_creacion_de_pedidos_en_rails7_api');
    expect((untraced.mock.calls[0][1]?.headers as Record<string, string>).traceparent).toBeUndefined();
  });

  it('raises ApiError with the server detail on failure', async () => {
    const client = createAutenticacionJwtYCreacionDePedidosEnRails7ApiClient({ fetch: fakeFetch(422, { detail: 'Command id is required' }) });
    await expect(client.execute('agg-1', 'process_autenticacion_jwt_y_creacion_de_pedidos_en_rails7_api')).rejects.toEqual(new ApiError(422, 'Command id is required'));
  });
});
