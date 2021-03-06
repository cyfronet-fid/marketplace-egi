# frozen_string_literal: true

class Jms::Publisher
  class ConnectionError < StandardError
    def initialize(msg)
      super(msg)
    end
  end

  def initialize(topic, login, pass, host, ssl_enabled, logger)
    @logger = logger

    conf_hash_res = conf_hash(login, pass, host, ssl_enabled)
    @client = Stomp::Client.new(conf_hash_res)
    @topic = topic

    verify_connection!
  end

  def publish(msg)
    @logger.info("Publishing to #{@topic}, message #{msg}")
    @client.publish(msg_destination, msg, msg_headers)
  end

  def close
    @client.close
  end

  private
    def conf_hash(login, pass, host, ssl)
      {
        hosts: [
          {
            login: login,
            passcode: pass,
            host: host,
            port: 61613,
            ssl: ssl,
          }
        ],
        connect_timeout: 5,
        max_reconnect_attempts: 5,
        connect_headers: {
          "accept-version": "1.2", # mandatory
          "host": "localhost", # mandatory
          "heart-beat": "0,20000",
        }
      }
    end

    def verify_connection!
      unless @client.open?
        raise ConnectionError.new("Connection failed!!")
      end
      if @client.connection_frame.command == Stomp::CMD_ERROR
        raise ConnectionError.new("Connection error: #{@client.connection_frame.body}")
      end
    end

    def msg_destination
      "/topic/#{@topic}"
    end

    def msg_headers
      {
        "persistent": true,
        # Without suppress_content_length ActiveMQ interprets the message as a BytesMessage, instead of a TextMessage.
        # See https://github.com/stompgem/stomp/blob/v1.4.10/lib/connection/netio.rb#L245
        # and https://activemq.apache.org/stomp.html.
        "suppress_content_length": true,
        "content-type": "application/json"
      }
    end
end
