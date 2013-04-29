require 'chef'

module TestMessages
  extend self

  @messages = []

  def reset
    @messages = []
  end

  def push(message)
    @messages << message
  end

  def read
    @messages
  end
end
