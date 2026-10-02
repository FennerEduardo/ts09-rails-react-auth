import { createAsyncThunk, createSlice } from '@reduxjs/toolkit';
import { CommandName, CommandResult, createAutenticacionJwtYCreacionDePedidosEnRails7ApiClient, AutenticacionJwtYCreacionDePedidosEnRails7ApiClient } from '../api/autenticacion-jwt-y-creacion-de-pedidos-en-rails7-api-client';

export interface AutenticacionJwtYCreacionDePedidosEnRails7ApiState {
  events: CommandResult[];
  status: 'idle' | 'loading' | 'failed';
  error: string | null;
}

const initialState: AutenticacionJwtYCreacionDePedidosEnRails7ApiState = { events: [], status: 'idle', error: null };

export interface ExecuteArgs {
  id: string;
  command: CommandName;
  payload?: Record<string, unknown>;
}

export const executeCommand = createAsyncThunk<CommandResult, ExecuteArgs, { extra: { client: AutenticacionJwtYCreacionDePedidosEnRails7ApiClient } }>(
  'autenticacionJwtYCreacionDePedidosEnRails7Api/execute',
  ({ id, command, payload }, { extra }) => extra.client.execute(id, command, payload, { idempotencyKey: crypto.randomUUID() })
);

const autenticacionJwtYCreacionDePedidosEnRails7ApiSlice = createSlice({
  name: 'autenticacionJwtYCreacionDePedidosEnRails7Api',
  initialState,
  reducers: {},
  extraReducers: builder => {
    builder
      .addCase(executeCommand.pending, state => {
        state.status = 'loading';
        state.error = null;
      })
      .addCase(executeCommand.fulfilled, (state, action) => {
        state.status = 'idle';
        state.events.push(action.payload);
      })
      .addCase(executeCommand.rejected, (state, action) => {
        state.status = 'failed';
        state.error = action.error.message ?? 'Request failed';
      });
  }
});

export const autenticacionJwtYCreacionDePedidosEnRails7ApiReducer = autenticacionJwtYCreacionDePedidosEnRails7ApiSlice.reducer;
export const defaultClient = () => createAutenticacionJwtYCreacionDePedidosEnRails7ApiClient({ baseUrl: import.meta.env.VITE_API_URL ?? '' });
