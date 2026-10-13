# frozen_string_literal: true

# POST /api/v1/autenticacion-jwt-y-creacion-de-pedidos-en-rails7-api/:id/:command (process_autenticacion_jwt_y_creacion_de_pedidos_en_rails7_api).
# ghk:implements AutenticacionJwtYCreacionDePedidosEnRails7Api
class AutenticacionJwtYCreacionDePedidosEnRails7ApiController < ApplicationController
  STATUS = { "created" => :accepted, "replayed" => :ok, "in-progress" => :conflict }.freeze

  class << self
    # The runtime kernel's CommandService (DATABASE_URL); tests assign a fake.
    attr_writer :commands

    def commands
      @commands ||= CommandService.new(ENV.fetch("DATABASE_URL"))
    end
  end

  def health
    render json: { status: "ok" }
  end

  def execute
    tenant = JwtTenant.tenant_from(request.headers["Authorization"])
    return render(json: { detail: "A valid bearer token with a tenant is required" }, status: :unauthorized) unless tenant

    payload = params.to_unsafe_h.except("controller", "action", "id", "command", "autenticacion_jwt_y_creacion_de_pedidos_en_rails7_api")
    result = self.class.commands.handle(tenant_id: tenant, aggregate_id: params[:id], command: params[:command], payload: payload,
                                        idempotency_key: request.headers["Idempotency-Key"], traceparent: request.headers["traceparent"],
                                        aggregate_type: "AutenticacionJwtYCreacionDePedidosEnRails7Api")
    render json: result.to_h, status: STATUS.fetch(result.status, :ok)
  rescue DomainValidationError => e
    render json: { detail: e.message }, status: :unprocessable_entity
  end
end
