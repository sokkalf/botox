require 'openssl'

$MAX_MESSAGE_LENGTH=450

module IRCConnection
  def get_config
    IRCConnection.get_config
  end

  def self.get_config
    @config = YAML.load_file('config.yml')
  end

  def self.get_server
    get_config['server'] ||= 'test'
  end

  def self.get_port
    get_config['port'] ||= 6667
  end

  def get_nick
    get_config['nick'] || 'botox'
  end

  def self.ssl?
    get_config['usessl'] || false
  end

  def connection
    IRCConnection.connection
  end

  def self.get_connection(server, port, ssl)
    connection = nil
    sock = TCPSocket.new(server, port)
    if ssl
      ctx = OpenSSL::SSL::SSLContext.new
#      ctx.set_params(verify_mode: OpenSSL::SSL::VERIFY_PEER)
#      ctx.ssl_version = :SSLv23
      connection = OpenSSL::SSL::SSLSocket.new(sock, ctx)
      connection.connect
    else
      connection = sock.connect
    end
    connection
  end

  def self.connection
    #@connection ||= TCPSocket.open(get_server, get_port)
    @connection ||= get_connection(get_server, get_port, ssl?)
  end

  def send_raw_message(message)
    unless message.length >= $MAX_MESSAGE_LENGTH
      connection.puts(message)
    end
  end

  def answer_ping(message)
    send_raw_message("PONG #{message}")
  end

  def join_channel(channel)
    send_raw_message("JOIN #{channel}")
  end

  def send_message_to_user(nick, message)
    send_raw_message("PRIVMSG #{nick} :#{message}")
  end

  def change_mode(user, channel, mode)
    send_raw_message("MODE #{channel} #{mode} #{user}")
  end

  def get_nick_from_prefix(prefix)
    prefix.split('!').first
  end
end

