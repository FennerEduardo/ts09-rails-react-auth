import { useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { COMMANDS } from '../api/autenticacion-jwt-y-creacion-de-pedidos-en-rails7-api-client';
import type { AppDispatch, RootState } from '../store/store';
import { executeCommand } from '../store/autenticacionJwtYCreacionDePedidosEnRails7ApiSlice';

export function AutenticacionJwtYCreacionDePedidosEnRails7ApiPanel() {
  const dispatch = useDispatch<AppDispatch>();
  const { events, status, error } = useSelector((s: RootState) => s.autenticacionJwtYCreacionDePedidosEnRails7Api);
  const [aggregateId, setAggregateId] = useState('');

  return (
    <section aria-label="Autenticación JWT y Creación de Pedidos en Rails 7 API">
      <h1>Autenticación JWT y Creación de Pedidos en Rails 7 API</h1>
      <label>
        Aggregate id
        <input value={aggregateId} onChange={e => setAggregateId(e.target.value)} />
      </label>
      {COMMANDS.map(command => (
        <button key={command} disabled={!aggregateId || status === 'loading'} onClick={() => dispatch(executeCommand({ id: aggregateId, command }))}>
          {command}
        </button>
      ))}
      {error && <p role="alert">{error}</p>}
      <ul aria-label="events">
        {events.map(e => (
          <li key={`${e.aggregateId}-${e.version}`}>
            {e.type} v{e.version}
          </li>
        ))}
      </ul>
    </section>
  );
}
