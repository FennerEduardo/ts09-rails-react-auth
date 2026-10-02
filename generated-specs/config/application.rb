require_relative "boot"

# API-only app without a database: load just the frameworks the generated code uses.
require "rails"
require "action_controller/railtie"

Bundler.require(*Rails.groups)

module RubyRailsReactAuth
  class Application < Rails::Application
    config.load_defaults 8.0
    config.api_only = true
    config.eager_load = ENV["RAILS_ENV"] == "production"
    config.secret_key_base = ENV.fetch("SECRET_KEY_BASE", "dev-secret-change-me")
    config.hosts.clear if Rails.env.test?
  end
end
