// React 18 + Redux Toolkit State & Client
import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import axios from 'axios';

export interface AutenticaciónJWTYCreaciónDePedidosEnRails7APIState {
  items: any[];
  selectedItem: any | null;
  loading: boolean;
  error: string | null;
  tenantId: string | null;
}

const initialState: AutenticaciónJWTYCreaciónDePedidosEnRails7APIState = {
  items: [],
  selectedItem: null,
  loading: false,
  error: null,
  tenantId: null
};

// Async Thunk to consume Backend API
export const fetchAutenticaciónJWTYCreaciónDePedidosEnRails7APIList = createAsyncThunk(
  'autenticaciónJWTYCreaciónDePedidosEnRails7API/fetchList',
  async (tenantId: string | undefined, { rejectWithValue }) => {
    try {
      const response = await axios.get(`/api/v1/autenticaciónJWTYCreaciónDePedidosEnRails7API`, {
        headers: tenantId ? { 'X-Tenant-ID': tenantId } : {}
      });
      return response.data;
    } catch (err: any) {
      return rejectWithValue(err.response?.data?.message || 'Error fetching data');
    }
  }
);

export const executeAutenticaciónJWTYCreaciónDePedidosEnRails7APICommand = createAsyncThunk(
  'autenticaciónJWTYCreaciónDePedidosEnRails7API/executeCommand',
  async (payload: { commandName: string; data: any; idempotencyKey?: string }, { rejectWithValue }) => {
    try {
      const headers: Record<string, string> = {};
      if (payload.idempotencyKey) {
        headers['X-Idempotency-Key'] = payload.idempotencyKey;
      }
      const response = await axios.post(`/api/v1/autenticaciónJWTYCreaciónDePedidosEnRails7API/commands`, payload.data, { headers });
      return response.data;
    } catch (err: any) {
      return rejectWithValue(err.response?.data?.message || 'Error executing command');
    }
  }
);

export const autenticaciónJWTYCreaciónDePedidosEnRails7APISlice = createSlice({
  name: 'autenticaciónJWTYCreaciónDePedidosEnRails7API',
  initialState,
  reducers: {
    setTenantId: (state, action: PayloadAction<string>) => {
      state.tenantId = action.payload;
    },
    onRealtimeEventReceived: (state, action: PayloadAction<{ eventType: string; payload: any }>) => {
      state.items.unshift(action.payload);
    },
    resetState: (state) => {
      Object.assign(state, initialState);
    }
  },
  extraReducers: (builder) => {
    builder
      .addCase(fetchAutenticaciónJWTYCreaciónDePedidosEnRails7APIList.pending, (state) => {
        state.loading = true;
        state.error = null;
      })
      .addCase(fetchAutenticaciónJWTYCreaciónDePedidosEnRails7APIList.fulfilled, (state, action) => {
        state.loading = false;
        state.items = action.payload;
      })
      .addCase(fetchAutenticaciónJWTYCreaciónDePedidosEnRails7APIList.rejected, (state, action) => {
        state.loading = false;
        state.error = action.payload as string;
      });
  }
});

export const { setTenantId, onRealtimeEventReceived, resetState } = autenticaciónJWTYCreaciónDePedidosEnRails7APISlice.actions;
export default autenticaciónJWTYCreaciónDePedidosEnRails7APISlice.reducer;
