class Plugins
  def kde_notify
    log_line = yield
    timestamp = log_line['timestamp']
    nick = get_nick_from_prefix(log_line['mask'])
    channel = log_line['channel']
    message = log_line['message']
    %x{kdialog --title 'IRC: #{channel}' --passivepopup '#{nick}: #{message}' 15} if message =~ /#{get_config['highlight']}/i
  end
end

