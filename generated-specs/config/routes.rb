Rails.application.routes.draw do
  get "health", to: "autenticacion_jwt_y_creacion_de_pedidos_en_rails7_api#health"
  post "api/v1/autenticacion-jwt-y-creacion-de-pedidos-en-rails7-api/:id/:command", to: "autenticacion_jwt_y_creacion_de_pedidos_en_rails7_api#execute"
end
