$LOAD_PATH.unshift File.dirname(__FILE__)
require 'irc_connection'

class Plugins
  include IRCConnection

  def initialize(ch)
    @handler = ch
  end

  def authenticated?(prefix)
    @handler.authenticated?(prefix)
  end

  def in_channel?(channel, nick)
    @handler.in_channel?(channel, nick)
  end

  def op_in_channel?(channel, nick)
    @handler.op_in_channel?(channel, nick)
  end

  def get_nick
    @handler.get_nick
  end
end

