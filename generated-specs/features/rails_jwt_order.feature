# language: es
Característica: Autenticación JWT y Creación de Pedidos en Rails 7 API

  Escenario: Emisión de Token JWT y Procesamiento de Transacción
    Dado que un cliente realiza POST a `/api/v1/users/sign_in` con credenciales válidas
    Entonces Rails API responde con HTTP 200 y el Header `Authorization: Bearer <jwt_token>`
    Cuando el cliente React envía POST a `/api/v1/orders` adjuntando el Bearer Token
    Entonces el `Api::V1::OrdersController` ejecuta el `CreateOrderService`
    Y RSpec valida que la transacción y la auditoría se persistan correctamente
