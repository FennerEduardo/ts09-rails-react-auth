RSpec.describe "AutenticacionJwtYCreacionDePedidosEnRails7Api API", type: :request do
  it "reports health" do
    get "/health"
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq("status" => "ok")
  end

  it "executes a domain command and returns the event" do
    post "/api/v1/autenticacion-jwt-y-creacion-de-pedidos-en-rails7-api/agg-api/process_autenticacion_jwt_y_creacion_de_pedidos_en_rails7_api", params: { source: "api-test" }, as: :json
    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to eq("type" => "ProcessAutenticacionJwtYCreacionDePedidosEnRails7ApiCompleted", "aggregateId" => "agg-api", "version" => 1)
  end

  it "returns 404 for unknown commands" do
    post "/api/v1/autenticacion-jwt-y-creacion-de-pedidos-en-rails7-api/agg-api/does_not_exist"
    expect(response).to have_http_status(:not_found)
  end
end
