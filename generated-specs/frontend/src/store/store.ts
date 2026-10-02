import { configureStore } from '@reduxjs/toolkit';
import { AutenticacionJwtYCreacionDePedidosEnRails7ApiClient } from '../api/autenticacion-jwt-y-creacion-de-pedidos-en-rails7-api-client';
import { defaultClient, autenticacionJwtYCreacionDePedidosEnRails7ApiReducer } from './autenticacionJwtYCreacionDePedidosEnRails7ApiSlice';

export function createAppStore(client: AutenticacionJwtYCreacionDePedidosEnRails7ApiClient = defaultClient()) {
  return configureStore({
    reducer: { autenticacionJwtYCreacionDePedidosEnRails7Api: autenticacionJwtYCreacionDePedidosEnRails7ApiReducer },
    middleware: getDefault => getDefault({ thunk: { extraArgument: { client } } })
  });
}

export type AppStore = ReturnType<typeof createAppStore>;
export type RootState = ReturnType<AppStore['getState']>;
export type AppDispatch = AppStore['dispatch'];
