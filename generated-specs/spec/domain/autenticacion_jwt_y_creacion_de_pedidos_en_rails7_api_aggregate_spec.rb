RSpec.describe AutenticacionJwtYCreacionDePedidosEnRails7ApiAggregate do
  subject(:aggregate) { described_class.new("agg-1") }

  it "starts in the initial state with no events" do
    expect(aggregate.state).to eq("PENDING")
    expect(aggregate.version).to eq(0)
    expect(aggregate.pending_events).to be_empty
  end

  it "rejects an aggregate without id" do
    expect { described_class.new("") }.to raise_error(DomainValidationError)
  end

  it "process_autenticacion_jwt_y_creacion_de_pedidos_en_rails7_api records ProcessAutenticacionJwtYCreacionDePedidosEnRails7ApiCompleted and bumps the version" do
    event = aggregate.process_autenticacion_jwt_y_creacion_de_pedidos_en_rails7_api(AutenticacionJwtYCreacionDePedidosEnRails7ApiCommand.new(id: "agg-1"))
    expect(event.type).to eq("ProcessAutenticacionJwtYCreacionDePedidosEnRails7ApiCompleted")
    expect(event.version).to eq(1)
    expect(aggregate.version).to eq(1)
    expect(aggregate.pending_events).to eq([event])
  end

  it "process_autenticacion_jwt_y_creacion_de_pedidos_en_rails7_api rejects a command without id" do
    expect { aggregate.process_autenticacion_jwt_y_creacion_de_pedidos_en_rails7_api(AutenticacionJwtYCreacionDePedidosEnRails7ApiCommand.new(id: "")) }.to raise_error(DomainValidationError)
    expect(aggregate.pending_events).to be_empty
  end
end
