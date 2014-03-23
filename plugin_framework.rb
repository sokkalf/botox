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
end

