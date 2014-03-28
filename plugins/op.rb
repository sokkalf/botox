class Plugins
  def give_op
    log_line = yield
    timestamp = log_line['timestamp']
    mask = log_line['mask']
    command = log_line['command']
    params = log_line['params']
    
    case command.upcase
      when 'OP' then
        matcher = params.match(/(\S+)\s*(.*)$/)
        unless matcher.nil?
          channel, user = matcher.captures
          pp channel
          pp user
          if op_in_channel?(channel, get_nick)
            if user.nil? && user.blank?
              change_mode(get_nick_from_prefix(mask), channel, '+o') if authenticated?(mask)
            else
              change_mode(user, channel, '+o') if authenticated?(mask)
            end
          else
            send_message_to_user(get_nick_from_prefix(mask), "I'm not in that channel, or not operator.")
          end
        end
    end
  end
end

