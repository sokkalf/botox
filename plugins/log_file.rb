class Plugins
  def log_message_to_file
    log_line = yield
    timestamp = log_line['timestamp']
    nick = log_line['mask']
    channel = log_line['channel']
    message = log_line['message']
    f = File.open("#{channel}.log", "a")
    f.puts "#{timestamp}: <#{get_nick_from_prefix(nick)}> #{message}"
    f.close
  end
end

register_plugin('channel', 'file_logger', 'log_message_to_file')
