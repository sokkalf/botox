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
        @ch.set_reconnect_wait_seconds(10) # reset wait timer on successful connect
        @ch.join_channels
      when '353' then
        channel = params.split[2]
        members = message.split.map do |member|
          user = Hash.new
          if member[/^\+/] then user['mode'] = 'voice'
          elsif member[/^@/] then user['mode'] = 'op'
          else user['mode'] = 'normal' end
          user['nick'] = member.match(/([^+@]\S*)/).captures.first
          user
        end
        @ch.update_channel_list(channel, members)
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
    if params == @ch.get_nick
      command, params = message.match(/^(\S*)\s*?(:?.*)$/).captures
      handle_bot_command(prefix, command, params)
    else
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
      when 'JOIN' then
        unless @ch.get_nick == get_nick_from_prefix(prefix)
          members = @ch.get_channel_members(message)
          joined_member = Hash.new
          joined_member['nick'] = get_nick_from_prefix(prefix)
          joined_member['mode'] = 'normal'
          members << joined_member
          @ch.update_channel_list(params, members)
        end
      when 'PART' then
        if @ch.get_nick == get_nick_from_prefix(prefix)
          @ch.update_channel_list(params, nil)
        else
          members = @ch.get_channel_members(params).select{|member| member['nick'] != get_nick_from_prefix(prefix)}
          @ch.update_channel_list(params, members)
        end
      when 'KICK' then
        channel, nick = params.match(/^(\S*)\s*(\S*)/).captures
        if nick == @ch.get_nick
          @ch.update_channel_list(channel, nil)
        else
          members = @ch.get_channel_members(channel).select{|member| member['nick'] != nick}
          @ch.update_channel_list(channel, members)
        end
      when 'MODE' then
        channel, mode, nick = params.match(/^(\S*)\s(\S*)\s(\S*)$/).captures
        members = @ch.get_channel_members(channel).map{|member|
          if member['nick'] == nick
            case mode
              when '+o' then member['mode'] = 'op'
              when '+v' then member['mode'] = 'voice'
              when '-o' then member['mode'] = 'normal'
              when '-v' then member['mode'] = 'normal'
            end
          end
          member
        }
        @ch.update_channel_list(channel, members)
      when 'ERROR' then
        if @ch.registering?
          puts "Error registering with IRC server: #{message}"
          exit 1
        end
    end
    if type =~ /[0-9][0-9][0-9]/
      handle_numeric(prefix, type, params, message)
    end
  end
end

class ConnectionHandler
  include IRCConnection

  def initialize
    @reconnect = true
    @reconnect_wait_seconds = 10
    @admins = Hash.new
    @authenticated_admins = Hash.new
    @registered = false
    @registering = false
    @channels_joined = Hash.new
    @startup_time = Time.now
    @plugins = Hash.new
    add_admins
    @eh = EventHandler.new(self)
    register
  end

  def reconnect?
    @reconnect
  end

  def get_reconnect_wait_seconds
    @reconnect_wait_seconds
  end

  def set_reconnect_wait_seconds(seconds)
    @reconnect_wait_seconds = seconds
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
    @plugins[type]
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
        @eh.send_message_to_user(get_nick_from_prefix(prefix), 'Sorry, authentication failed.')
      end
    else
      @eh.send_message_to_user(get_nick_from_prefix(prefix), 'You are already authenticated.')
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
    @registered = r
    @registering = false
  end

  def register
    @registering = true
    unless get_config['password'].nil?
      send_raw_message("PASS #{get_config['password']}")
    end
    send_raw_message("NICK #{get_nick}")
    send_raw_message('USER botox 0 * :botox IRC Bot')
  end

  def update_channel_list(channel, members)
    @channels_joined[channel] = members
  end

  def get_channel_members(channel)
    @channels_joined[channel] ||= []
  end

  def in_channel?(channel, nick)
    result = get_channel_members(channel.strip).select {|member| member['nick'] == nick.strip}
    !result.nil? && !result.empty?
  end

  def op_in_channel?(channel, nick)
    result = get_channel_members(channel.strip).select {|member| member['nick'] == nick.strip && member['mode'] == 'op'}
    !result.nil? && !result.empty?
  end

  def join_channels
    channels = get_config['channels']
    unless channels.nil?
      channels.each do |channel|
        join_channel(channel)
      end
    end
  end

  def wipe_channels
    @channels_joined = Hash.new
  end

  def raw_message_handler(raw_message)
    prefix, type, params, message = raw_message.match(/^(?:[:](\S+) )?(\S+)(?: (?!:)(.+?))?(?: [:](.*))?$/).captures
    @eh.handle_event(prefix, type, params, message)
  end

  def connection_listener
    until connection.eof? do
      string = connection.readline.chomp.dup
      string.force_encoding('UTF-8')
      if !string.valid_encoding?
        string.force_encoding('CP1252').encode!('UTF-8', {:invalid => :replace, :undef => :replace})
      end
      raw_message_handler(string)
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
# register plugins
eval(File.open('register_plugins.rb').read)

while @ch.reconnect? do
  @ch.connection_listener
  puts "Connection lost, retrying in #{@ch.get_reconnect_wait_seconds} seconds."
  @ch.send_raw_message('') # send 'nothing' to trigger a broken pipe, which again triggers a reconnect
  @ch.set_registered(false)
  @ch.wipe_channels
  sleep(@ch.get_reconnect_wait_seconds)
  @ch.send_raw_message('')
  @ch.set_reconnect_wait_seconds(@ch.get_reconnect_wait_seconds * 2) # increase wait between each retry
  @ch.register
end

