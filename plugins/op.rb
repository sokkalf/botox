class Plugins
  def give_op
    log_line = yield
    timestamp = log_line['timestamp']
    mask = log_line['mask']
    command = log_line['command']
    params = log_line['params']
    
    case command.upcase
      when 'OP' then
        if op_in_channel?(params, get_nick)
          change_mode(get_nick_from_prefix(mask), params, '+o') if authenticated?(mask)
        else
          send_message_to_user(get_nick_from_prefix(mask), "I'm not in that channel, or not operator.")
        end
    end
  end
end

