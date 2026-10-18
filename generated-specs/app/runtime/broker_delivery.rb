# frozen_string_literal: true

# A received message: ack once processed; dead_letter moves it to the DLQ (it is not redelivered).
BrokerDelivery = Struct.new(:message, :on_ack, :on_dead_letter) do
  def ack
    on_ack.call
  end

  def dead_letter
    on_dead_letter.call
  end
end
