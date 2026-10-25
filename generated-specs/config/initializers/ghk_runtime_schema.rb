# The runtime kernel's tables, created when the app boots (the server, and rake outbox:relay): idempotent and
# serialized across replicas. GHK_MIGRATE=false when a migration job owns the schema; the test suites
# migrate their own schemas.
Rails.application.config.after_initialize do
  if ENV["DATABASE_URL"].to_s != "" && ENV["GHK_MIGRATE"] != "false" && !Rails.env.test?
    RuntimeSchema.migrate(ENV.fetch("DATABASE_URL"))
  end
end
