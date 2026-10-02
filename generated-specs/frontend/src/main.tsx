import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { Provider } from 'react-redux';
import { AutenticacionJwtYCreacionDePedidosEnRails7ApiPanel } from './components/AutenticacionJwtYCreacionDePedidosEnRails7ApiPanel';
import { createAppStore } from './store/store';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <Provider store={createAppStore()}>
      <AutenticacionJwtYCreacionDePedidosEnRails7ApiPanel />
    </Provider>
  </StrictMode>
);
