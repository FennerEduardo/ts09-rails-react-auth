# frozen_string_literal: true

AutenticacionJwtYCreacionDePedidosEnRails7ApiCommand = Data.define(:id, :payload) do
  def initialize(id:, payload: {})
    super
  end
end
