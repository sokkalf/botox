require 'elasticsearch'
require 'json'

class Plugins
  def get_elasticsearch_client
    Plugins.get_elasticsearch_client
  end

  def self.get_elasticsearch_client
    @client ||= Elasticsearch::Client.new log: false
  end

  def log_message_to_elasticsearch
    log_line = yield
    #client = Elasticsearch::Client.new log: false
    response = get_elasticsearch_client.index index: 'irc_log', type: 'irc_message', body: log_line.to_json
  end
end

