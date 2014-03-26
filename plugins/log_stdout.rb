class Plugins
  def log_message
    log_line = yield
    timestamp = log_line['timestamp']
    nick = log_line['mask']
    channel = log_line['channel']
    message = log_line['message']
    puts "#{timestamp}: <#{get_nick_from_prefix(nick)}> #{message}"
  end
end

