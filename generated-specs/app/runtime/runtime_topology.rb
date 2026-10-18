# frozen_string_literal: true

# Event bus destinations: publish to exchange (topic), consume from queue (subscription);
# dead-lettered messages go to dlx and are read from dlq.
RuntimeTopology = Struct.new(:exchange, :queue, :dlx, :dlq) do
  def self.default
    new("ruby-rails-react-auth.events", "ruby-rails-react-auth.consumer", "ruby-rails-react-auth.dlx", "ruby-rails-react-auth.dlq")
  end

  def self.for_prefix(prefix)
    new("#{prefix}.events", "#{prefix}.consumer", "#{prefix}.dlx", "#{prefix}.dlq")
  end
end
