import { configureStore } from '@reduxjs/toolkit';
import type { AutenticacionJwtYCreacionDePedidosEnRails7ApiClient } from '../api/autenticacion-jwt-y-creacion-de-pedidos-en-rails7-api-client';
import { defaultClient as defaultAutenticacionJwtYCreacionDePedidosEnRails7ApiClient, autenticacionJwtYCreacionDePedidosEnRails7ApiReducer } from './autenticacionJwtYCreacionDePedidosEnRails7ApiSlice';

/** One API client per feature of the service (each slice uses its own). */
export interface AppClients {
  autenticacionJwtYCreacionDePedidosEnRails7Api: AutenticacionJwtYCreacionDePedidosEnRails7ApiClient;
}

export function createAppStore(clients: Partial<AppClients> = {}) {
  const extraArgument: { clients: AppClients } = {
    clients: {
      autenticacionJwtYCreacionDePedidosEnRails7Api: clients.autenticacionJwtYCreacionDePedidosEnRails7Api ?? defaultAutenticacionJwtYCreacionDePedidosEnRails7ApiClient(),
    }
  };
  return configureStore({
    reducer: { autenticacionJwtYCreacionDePedidosEnRails7Api: autenticacionJwtYCreacionDePedidosEnRails7ApiReducer },
    middleware: getDefault => getDefault({ thunk: { extraArgument } })
  });
}

export type AppStore = ReturnType<typeof createAppStore>;
export type RootState = ReturnType<AppStore['getState']>;
export type AppDispatch = AppStore['dispatch'];
