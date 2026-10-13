# frozen_string_literal: true

# HTTP contract of the application layer against PostgreSQL (needs DATABASE_URL).
RSpec.describe "AutenticacionJwtYCreacionDePedidosEnRails7Api HTTP application layer", :integration, type: :request do
  secret = "integration-test-secret-with-32-chars!"

  around do |example|
    previous = ENV["JWT_SECRET"]
    ENV["JWT_SECRET"] = secret
    RuntimeSchema.migrate(ENV.fetch("DATABASE_URL"))
    AutenticacionJwtYCreacionDePedidosEnRails7ApiController.commands = nil
    example.run
  ensure
    ENV["JWT_SECRET"] = previous
  end

  it "runs a command into the outbox for the token tenant, idempotently" do
    tenant = "tenant-#{SecureRandom.hex(6)}"
    id = "agg-#{SecureRandom.hex(6)}"
    url = "/api/v1/autenticacion-jwt-y-creacion-de-pedidos-en-rails7-api/#{id}/process_autenticacion_jwt_y_creacion_de_pedidos_en_rails7_api"
    post url, headers: { "X-Tenant-Id" => tenant }
    expect(response).to have_http_status(:unauthorized)

    headers = { "Authorization" => "Bearer #{JwtTenant.sign({ JwtTenant::TENANT_CLAIM => tenant }, secret)}", "Idempotency-Key" => SecureRandom.hex(8), "X-Tenant-Id" => "someone-else" }
    post url, headers: headers
    expect(response).to have_http_status(:accepted)
    post url, headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["status"]).to eq("replayed")

    conn = PG.connect(ENV.fetch("DATABASE_URL"))
    rows = conn.exec_params("SELECT tenant_id FROM ghk_outbox WHERE aggregate_id = $1", [id]).to_a
    conn.close
    expect(rows).to eq([{ "tenant_id" => tenant }])
  end
end
