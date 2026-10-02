import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { Provider } from 'react-redux';
import { createAppStore } from '../store/store';
import { AutenticacionJwtYCreacionDePedidosEnRails7ApiPanel } from './AutenticacionJwtYCreacionDePedidosEnRails7ApiPanel';
import type { AutenticacionJwtYCreacionDePedidosEnRails7ApiClient } from '../api/autenticacion-jwt-y-creacion-de-pedidos-en-rails7-api-client';

describe('AutenticacionJwtYCreacionDePedidosEnRails7ApiPanel', () => {
  it('executes a command and lists the resulting event', async () => {
    const client = { execute: vi.fn().mockResolvedValue({ type: 'ProcessAutenticacionJwtYCreacionDePedidosEnRails7ApiCompleted', aggregateId: 'agg-1', version: 1 }) } as unknown as AutenticacionJwtYCreacionDePedidosEnRails7ApiClient;
    render(
      <Provider store={createAppStore(client)}>
        <AutenticacionJwtYCreacionDePedidosEnRails7ApiPanel />
      </Provider>
    );

    await userEvent.type(screen.getByLabelText('Aggregate id'), 'agg-1');
    await userEvent.click(screen.getByRole('button', { name: 'process_autenticacion_jwt_y_creacion_de_pedidos_en_rails7_api' }));

    expect(await screen.findByText('ProcessAutenticacionJwtYCreacionDePedidosEnRails7ApiCompleted v1')).toBeInTheDocument();
    expect(client.execute).toHaveBeenCalledWith('agg-1', 'process_autenticacion_jwt_y_creacion_de_pedidos_en_rails7_api', undefined, expect.objectContaining({ idempotencyKey: expect.any(String) }));
  });

  it('disables commands until an aggregate id is entered', () => {
    render(
      <Provider store={createAppStore({ execute: vi.fn() } as unknown as AutenticacionJwtYCreacionDePedidosEnRails7ApiClient)}>
        <AutenticacionJwtYCreacionDePedidosEnRails7ApiPanel />
      </Provider>
    );
    expect(screen.getByRole('button', { name: 'process_autenticacion_jwt_y_creacion_de_pedidos_en_rails7_api' })).toBeDisabled();
  });
});
