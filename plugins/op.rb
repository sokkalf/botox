class Plugins
  def give_op
    log_line = yield
    timestamp = log_line['timestamp']
    mask = log_line['mask']
    command = log_line['command']
    params = log_line['params']
    
    case command.upcase
      when 'OP' then
        change_mode(get_nick_from_prefix(mask), params, '+o') if authenticated?(mask)
    end
  end
end

register_plugin('bot_command', 'op_plugin', 'give_op')
