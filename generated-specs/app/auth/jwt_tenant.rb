# frozen_string_literal: true

require "base64"
require "json"
require "openssl"

# HS256 bearer tokens. The tenant comes only from the "tenant_id" claim of a validated token, never from a
# header such as X-Tenant-Id, and there is no default tenant.
module JwtTenant
  TENANT_CLAIM = "tenant_id"

  module_function

  # Tenant claim of a valid token (signature, exp, nbf checked), else nil.
  def tenant_from(authorization, secret = ENV.fetch("JWT_SECRET", ""))
    return nil if secret.to_s.empty? || !authorization.to_s.match?(/\ABearer /i)

    head, body, sig = authorization.to_s[7..].strip.split(".")
    return nil unless head && body && sig
    return nil unless JSON.parse(decode(head))["alg"] == "HS256"

    expected = OpenSSL::HMAC.digest("SHA256", secret, "#{head}.#{body}")
    given = decode(sig)
    return nil unless given.bytesize == expected.bytesize && OpenSSL.fixed_length_secure_compare(given, expected)

    claims = JSON.parse(decode(body))
    now = Time.now.to_i
    return nil if claims["exp"].is_a?(Numeric) && now >= claims["exp"]
    return nil if claims["nbf"].is_a?(Numeric) && now < claims["nbf"]

    tenant = claims[TENANT_CLAIM]
    tenant.is_a?(String) && !tenant.strip.empty? ? tenant : nil
  rescue JSON::ParserError, ArgumentError, NoMethodError
    nil
  end

  # Signs an HS256 token (tests and local tooling; production tokens come from your identity provider).
  def sign(claims, secret)
    head = encode({ alg: "HS256", typ: "JWT" }.to_json)
    body = encode(claims.to_json)
    "#{head}.#{body}.#{encode(OpenSSL::HMAC.digest("SHA256", secret, "#{head}.#{body}"))}"
  end

  def decode(part) = Base64.urlsafe_decode64(part + ("=" * ((4 - (part.length % 4)) % 4)))
  def encode(data) = Base64.urlsafe_encode64(data, padding: false)
end
