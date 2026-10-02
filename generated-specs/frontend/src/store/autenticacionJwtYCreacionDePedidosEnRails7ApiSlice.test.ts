import { describe, expect, it, vi } from 'vitest';
import { createAppStore } from './store';
import { executeCommand } from './autenticacionJwtYCreacionDePedidosEnRails7ApiSlice';
import type { AutenticacionJwtYCreacionDePedidosEnRails7ApiClient } from '../api/autenticacion-jwt-y-creacion-de-pedidos-en-rails7-api-client';

describe('autenticacionJwtYCreacionDePedidosEnRails7Api slice', () => {
  it('records the event returned by the backend', async () => {
    const result = { type: 'ProcessAutenticacionJwtYCreacionDePedidosEnRails7ApiCompleted', aggregateId: 'agg-1', version: 1 };
    const client = { execute: vi.fn().mockResolvedValue(result) } as unknown as AutenticacionJwtYCreacionDePedidosEnRails7ApiClient;
    const store = createAppStore(client);

    await store.dispatch(executeCommand({ id: 'agg-1', command: 'process_autenticacion_jwt_y_creacion_de_pedidos_en_rails7_api' }));

    expect(store.getState().autenticacionJwtYCreacionDePedidosEnRails7Api).toEqual({ events: [result], status: 'idle', error: null });
  });

  it('keeps the error message when the command fails', async () => {
    const client = { execute: vi.fn().mockRejectedValue(new Error('Command id is required')) } as unknown as AutenticacionJwtYCreacionDePedidosEnRails7ApiClient;
    const store = createAppStore(client);

    await store.dispatch(executeCommand({ id: 'agg-1', command: 'process_autenticacion_jwt_y_creacion_de_pedidos_en_rails7_api' }));

    expect(store.getState().autenticacionJwtYCreacionDePedidosEnRails7Api.status).toBe('failed');
    expect(store.getState().autenticacionJwtYCreacionDePedidosEnRails7Api.error).toBe('Command id is required');
  });
});
