require 'socket'
require 'yaml'
require 'pp'
$LOAD_PATH.unshift File.dirname(__FILE__)
require 'irc_connection'
require 'plugin_framework'

class EventHandler
  include IRCConnection

  def initialize(connection_handler)
    @ch = connection_handler
  end

  def handle_numeric(prefix, numeric, params, message)
    case numeric
      when '001' then 
        @ch.set_registered(true)
        @ch.join_channels
      when '353' then
        channel = params.split[2]
        members = message.split.map do |member|
          user = Hash.new
          if member[/^\+/] then user['mode'] = 'voice'
          elsif member[/^@/] then user['mode'] = 'op'
          else user['mode'] = 'normal' end
          user['nick'] = member.match(/([^+@]\S*)/).captures
          user
        end
        pp members
    end
  end

  def handle_bot_command(prefix, command, params)
    case command.upcase
      when 'STATUS' then 
        if @ch.authenticated?(prefix)
          send_message_to_user(get_nick_from_prefix(prefix), "Hello, authenticated user #{get_nick_from_prefix(prefix)}. I am #{get_nick}, and I have been running since #{@ch.get_startup_time}")
        else
          send_message_to_user(get_nick_from_prefix(prefix), "Hello, #{get_nick_from_prefix(prefix)}. I am #{get_nick}, and I have been running since #{@ch.get_startup_time}.")
        end
      when 'AUTH' then
        username, password = params.split
        @ch.authenticate_admin(prefix, username, password)
      else
        bot_command_data = Hash.new
        bot_command_data['timestamp'] = Time.now
        bot_command_data['mask'] = prefix
        bot_command_data['command'] = command
        bot_command_data['params'] = params
        @ch.get_plugins('bot_command').each do |plugin|
          plugin['func'].call { bot_command_data }
        end
    end 
  end

  def handle_private_message(prefix, params, message)
    puts "#{get_nick_from_prefix(prefix)} - #{params} - #{message}"
    if params == @ch.get_nick
      command, params = message.match(/^(\S*)\s*?(:?.*)$/).captures
      handle_bot_command(prefix, command, params)
    else
      puts "#{get_nick_from_prefix(prefix)} - #{params} - #{message}"
      channel_data = Hash.new
      channel_data['timestamp'] = Time.now
      channel_data['mask'] = prefix
      channel_data['channel'] = params
      channel_data['message'] = message
      @ch.get_plugins('channel').each do |plugin|
        plugin['func'].call { channel_data }
      end
    end
  end

  def handle_event(prefix, type, params, message)
    case type.upcase
      when 'PING' then answer_ping(message)
      when 'PRIVMSG' then handle_private_message(prefix, params, message)
      when 'ERROR' then
        if @ch.registering?
          puts "Error registering with IRC server: #{message}"
          exit 1
        end
    end
    if type =~ /[0-9][0-9][0-9]/
      handle_numeric(prefix, type, params, message)
    end
    puts "'#{prefix}' '#{type}' '#{params}' '#{message}'"
  end
end

class ConnectionHandler
  include IRCConnection

  def initialize
    @admins = Hash.new
    @authenticated_admins = Hash.new
    @registered = false
    @registering = false
    @startup_time = Time.now
    @plugins = Hash.new
    add_admins
    @eh = EventHandler.new(self)
    register
  end

  def register_plugin(type, name, func)
    if @plugins[type].nil?
      @plugins[type] = []
    end
    puts "Registering #{type} plugin '#{name}'"
    plugin = Hash.new
    plugin['name'] = name
    plugin['func'] = func
    @plugins[type] << plugin
  end
 
  def get_plugins(type)
    registered_plugins = @plugins[type]
    registered_plugins ||= []
  end

  def get_startup_time
    @startup_time
  end

  def add_admins
    admins = get_config['admins']
    unless admins.nil?
      admins.each do |admin|
        username = admin['username']
        password = admin['password']
        @admins[username] = password
      end
    end
  end

  def authenticate_admin(prefix, username, password)
    if @authenticated_admins[prefix].nil?
      if @admins[username] == password
        @authenticated_admins[prefix] = username
        @eh.send_message_to_user(get_nick_from_prefix(prefix), "Greetings, #{@eh.get_nick_from_prefix(prefix)}, you are authenticated as #{username}.")
      else
        @eh.send_message_to_user(get_nick_from_prefix(prefix), "Sorry, authentication failed.")
      end
    else
      @eh.send_message_to_user(get_nick_from_prefix(prefix), "You are already authenticated.")
    end
  end

  def authenticated?(prefix)
    !@authenticated_admins[prefix].nil?
  end

  def registered?
    @registered
  end

  def registering?
    @registering
  end

  def set_registered(r)
    puts 'Setting registered'
    @registered = r
    @registering = false
  end

  def register
    @registering = true
    unless get_config['password'].nil?
      send_raw_message("pass #{get_config['password']}")
    end
    send_raw_message('user botox 0 * :botox IRC Bot')
    send_raw_message("nick #{get_nick}")
  end

  def join_channels
    channels = get_config['channels']
    unless channels.nil?
      channels.each do |channel|
        join_channel(channel)
      end
    end
  end

  def raw_message_handler(raw_message)
    #puts raw_message
    prefix, type, params, message = raw_message.match(/^(?:[:](\S+) )?(\S+)(?: (?!:)(.+?))?(?: [:](.+))?$/).captures
    @eh.handle_event(prefix, type, params, message)
  end

  def connection_listener
    until connection.eof? do
      raw_message_handler(connection.gets.chomp)
    end
  end
end

@ch = ConnectionHandler.new

@plugins = Plugins.new(@ch)

def register_plugin(type, name, method_name)
  @ch.register_plugin(type, name, @plugins.method(method_name.to_sym))
end

# read plugins
Dir.glob('plugins/*.rb').each do |filename|
  eval(File.open(filename).read)
end

@ch.connection_listener

