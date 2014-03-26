class Plugins
  def set_topic
    log_line = yield
    timestamp = log_line['timestamp']
    mask = log_line['mask']
    command = log_line['command']
    params = log_line['params']
    
    case command.upcase
      when 'TOPIC' then
        matcher = params.match(/(\S+)\s*(.*)$/)
        unless matcher.nil?
          channel, topic = matcher.captures
          puts "Setting topic for channel #{channel} to #{topic}"
          if op_in_channel?(channel, get_nick)
            send_raw_message("TOPIC #{channel} :#{topic}") if authenticated?(mask)
          else
            send_message_to_user(get_nick_from_prefix(mask), "I'm not in that channel, or not operator.")
          end
        end
    end
  end
end

