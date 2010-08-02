require "digest/md5"
require "uri"
require "net/https"

begin
  require "rubygems"
rescue LoadError
end
require "active_support"

module Mollie
  class SMS
    GATEWAY_URI = URI.parse("https://secure.mollie.nl/xml/sms")

    GATEWAYS = {
      'basic'     => '2',
      'business'  => '4',
      'business+' => '1',
      'landline'  => '8'
    }

    class StandardError        < ::StandardError; end
    class ValidationError      < StandardError; end
    class MissingRequiredParam < StandardError; end

    REQUIRED_PARAMS = %w{ username md5_password originator gateway charset type recipients message }

    class << self
      attr_accessor :username, :password, :originator, :charset, :type, :gateway

      def password=(password)
        @password = Digest::MD5.hexdigest(password)
      end

      def default_params
        {
          'username'     => @username,
          'md5_password' => @password,
          'originator'   => @originator,
          'gateway'      => @gateway,
          'charset'      => @charset,
          'type'         => @type
        }
      end
    end

    self.charset = 'UTF-8'
    self.type    = 'normal'
    self.gateway = GATEWAYS['basic']

    attr_reader :params

    def initialize(telephone_number = nil, body = nil, extra_params = {})
      @params = self.class.default_params.merge(extra_params)
      self.telephone_number = telephone_number if telephone_number
      self.body = body if body
    end

    def telephone_number
      @params['recipients']
    end

    def telephone_number=(telephone_number)
      @params['recipients'] = telephone_number
    end

    def body
      @params['message']
    end

    def body=(body)
      @params['message'] = body
    end

    def inspect
      "#<#{self.class.name} from: <#{@params['originator']}> to: <#{telephone_number}> body: \"#{body}\" >"
    end

    def deliver
      validate_params!

      post = Net::HTTP::Post.new(GATEWAY_URI.path)
      post.form_data = params
      request = Net::HTTP.new(GATEWAY_URI.host, GATEWAY_URI.port)
      request.use_ssl = true
      request.start do |http|
        response = http.request(post)
        Response.new(response)
      end
    end

    def validate_params!
      params.slice(*REQUIRED_PARAMS).each do |key, value|
        raise MissingRequiredParam, "The required parameter `#{key}' is missing." if value.blank?
      end

      originator = params['originator']
      if originator =~ /^\d+$/
        if originator.size > 14
          raise ValidationError, "Originator may have a maximimun of 14 numerical characters."
        end
      elsif originator.size > 11
        raise ValidationError, "Originator may have a maximimun of 11 alphanumerical characters."
      end
    end

    class Response
      attr_reader :http_response

      def initialize(http_response)
        @http_response = http_response
      end

      def params
        @params ||= http_failure? ? {} : Hash.from_xml(@http_response.read_body)['response']['item']
      end

      def result_code
        (http_failure? ? @http_response.code : params['resultcode']).to_i
      end

      def message
        http_failure? ? "[HTTP: #{@http_response.code}] #{@http_response.message}" : params['resultmessage']
      end

      def success?
        !http_failure? && params['success'] == 'true'
      end

      def http_failure?
        !@http_response.is_a?(Net::HTTPSuccess)
      end

      def inspect
        "#<#{self.class.name} #{ success? ? 'succeeded' : 'failed' } (#{result_code}) `#{message}'>"
      end
    end
  end
end
