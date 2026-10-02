# frozen_string_literal: true

class AutenticacionJwtYCreacionDePedidosEnRails7ApiController < ApplicationController
  COMMANDS = %w[process_autenticacion_jwt_y_creacion_de_pedidos_en_rails7_api].freeze

  def health
    render json: { status: "ok" }
  end

  def execute
    command = params[:command]
    return render(json: { detail: "Unknown command #{command}" }, status: :not_found) unless COMMANDS.include?(command)

    # In-memory aggregate: replace with a repository + outbox.
    aggregate = AutenticacionJwtYCreacionDePedidosEnRails7ApiAggregate.new(params[:id])
    payload = params.to_unsafe_h.except("controller", "action", "id", "command", "autenticacion_jwt_y_creacion_de_pedidos_en_rails7_api")
    event = aggregate.public_send(command, AutenticacionJwtYCreacionDePedidosEnRails7ApiCommand.new(id: params[:id], payload: payload))
    render json: { type: event.type, aggregateId: event.aggregate_id, version: event.version }, status: :created
  rescue DomainValidationError => e
    render json: { detail: e.message }, status: :unprocessable_entity
  end
end
