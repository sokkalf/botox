require 'elasticsearch'
require 'json'

class Plugins
  def log_message_to_elasticsearch
    log_line = yield
    client = Elasticsearch::Client.new log: false
    response = client.index index: 'irc_log', type: 'irc_message', body: log_line.to_json
  end
end

register_plugin('channel', 'elasticsearch_logger', 'log_message_to_elasticsearch')
