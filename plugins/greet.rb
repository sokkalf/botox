class Plugins
  def greet
    log_line = yield
    timestamp = log_line['timestamp']
    nick = log_line['mask']
    channel = log_line['channel']
    message = log_line['message']
    
    command, params = ''
    matches = message.match(/^!(\S*)\s*?(:?.*)$/)
    command, params = matches.captures if matches
    case command.upcase
      when 'GREET' then 
        unless params.empty?
          if authenticated?(nick)
            send_message_to_user(channel, "Greetings, #{params}!")
          end
        end
    end
  end
end

register_plugin('channel', 'greeting_plugin', 'greet')
