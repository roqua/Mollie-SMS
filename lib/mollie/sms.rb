require "digest/md5"
require "uri"
require "net/http"

begin
  require "rubygems"
rescue LoadError
end
require "active_support"

module Mollie
  class SMS
    GATEWAY_URI = URI.parse("http://www.mollie.nl/xml/sms")

    GATEWAYS = {
      :basic         => '2',
      :business      => '4',
      :business_plus => '1',
      :landline      => '8'
    }

    class << self
      attr_accessor :username, :password, :charset, :type, :gateway

      def password=(password)
        @password = Digest::MD5.hexdigest(password)
      end

      def request_params
        {
          'username'     => @username,
          'md5_password' => @password,
          'gateway'      => @gateway,
          'charset'      => @charset,
          'type'         => @type
        }
      end
    end

    self.charset = 'UTF-8'
    self.type    = 'normal'
    self.gateway = GATEWAYS[:basic]    

    attr_accessor :telephone_number, :body

    def request_params
      self.class.request_params.merge('recipients' => @telephone_number, 'message' => @body)
    end

    def deliver
      Response.new(Net::HTTP.post_form(GATEWAY_URI, request_params))
    end

    class Response
      attr_reader :http_response

      def initialize(http_response)
        @http_response = http_response
      end

      def params
        @params ||= Hash.from_xml(@http_response.read_body)['response']['item']
      end

      def result_code
        params['resultcode'].to_i
      end

      def message
        params['resultmessage']
      end

      def success?
        @http_response.is_a?(Net::HTTPSuccess) && params['success'] == 'true'
      end
    end
  end
end
