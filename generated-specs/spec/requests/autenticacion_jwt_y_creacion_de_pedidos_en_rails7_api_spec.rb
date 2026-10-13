# frozen_string_literal: true

RSpec.describe "AutenticacionJwtYCreacionDePedidosEnRails7Api API", type: :request do
  secret = "unit-test-secret-with-at-least-32-chars"

  fake = Class.new do
    attr_reader :calls

    def initialize = @calls = []

    def handle(tenant_id:, aggregate_id:, command:, payload: {}, idempotency_key: nil, traceparent: nil, aggregate_type: nil)
      @calls << [tenant_id, aggregate_id, command, payload]
      raise DomainValidationError, "Unknown command #{command}" if command == "does_not_exist"

      CommandService::Result.new(status: idempotency_key == "seen" ? "replayed" : "created", aggregate_id: aggregate_id, event_type: "ProcessAutenticacionJwtYCreacionDePedidosEnRails7ApiCompleted", version: 1)
    end
  end

  let(:commands) { fake.new }
  let(:bearer) { ->(claims, key = secret) { { "Authorization" => "Bearer #{JwtTenant.sign(claims, key)}" } } }

  around do |example|
    previous = ENV["JWT_SECRET"]
    ENV["JWT_SECRET"] = secret
    AutenticacionJwtYCreacionDePedidosEnRails7ApiController.commands = commands
    example.run
  ensure
    ENV["JWT_SECRET"] = previous
    AutenticacionJwtYCreacionDePedidosEnRails7ApiController.commands = nil
  end

  it "reports health" do
    get "/health"
    expect(response).to have_http_status(:ok)
  end

  it "runs a command for the token tenant" do
    post "/api/v1/autenticacion-jwt-y-creacion-de-pedidos-en-rails7-api/agg-api/process_autenticacion_jwt_y_creacion_de_pedidos_en_rails7_api", params: { source: "api-test" }, as: :json,
                                                   headers: bearer.call({ JwtTenant::TENANT_CLAIM => "acme" }).merge("X-Tenant-Id" => "someone-else")
    expect(response).to have_http_status(:accepted)
    expect(commands.calls.last).to eq(["acme", "agg-api", "process_autenticacion_jwt_y_creacion_de_pedidos_en_rails7_api", { "source" => "api-test" }])
  end

  it "returns 200 for an idempotent replay" do
    post "/api/v1/autenticacion-jwt-y-creacion-de-pedidos-en-rails7-api/agg-api/process_autenticacion_jwt_y_creacion_de_pedidos_en_rails7_api", headers: bearer.call({ JwtTenant::TENANT_CLAIM => "acme" }).merge("Idempotency-Key" => "seen")
    expect(response).to have_http_status(:ok)
  end

  it "rejects missing or invalid tokens and X-Tenant-Id" do
    url = "/api/v1/autenticacion-jwt-y-creacion-de-pedidos-en-rails7-api/agg-api/process_autenticacion_jwt_y_creacion_de_pedidos_en_rails7_api"
    [{}, { "X-Tenant-Id" => "acme" }, bearer.call({ "sub" => "u1" }), bearer.call({ JwtTenant::TENANT_CLAIM => "acme" }, "wrong")].each do |headers|
      post url, headers: headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  it "maps domain validation errors to 422" do
    post "/api/v1/autenticacion-jwt-y-creacion-de-pedidos-en-rails7-api/agg-api/does_not_exist", headers: bearer.call({ JwtTenant::TENANT_CLAIM => "acme" })
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
