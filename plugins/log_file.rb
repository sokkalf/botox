class Plugins
  def open_logfile(channel)
    Plugins.open_logfile[channel] ||= File.open("#{channel}.log", "a")
  end

  def self.open_logfile
    @logfiles ||= Hash.new
  end

  def log_message_to_file
    log_line = yield
    timestamp = log_line['timestamp']
    nick = log_line['mask']
    channel = log_line['channel']
    message = log_line['message']
    f = open_logfile(channel) #File.open("#{channel}.log", "a")
    f.puts "#{timestamp}: <#{get_nick_from_prefix(nick)}> #{message}"
    f.flush
  end
end

