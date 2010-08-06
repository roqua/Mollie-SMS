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

    class DeliveryFailure < StandardError
      attr_reader :sms, :response

      def initialize(sms, response)
        @sms, @response = sms, response
      end

      def message
        "(#{@response.message}) #{@sms.to_s}"
      end
    end

    REQUIRED_PARAMS = %w{ username md5_password originator gateway charset type recipients message }

    class << self
      attr_reader :password
      attr_accessor :username, :originator, :charset, :type, :gateway

      # Assigns a MD5 hashed version of the given +password+.
      #
      # @param [String] password
      def password=(password)
        @password = Digest::MD5.hexdigest(password)
      end

      # Returns the default parameters that will be we merged with each
      # instance’s params.
      #
      # This includes +username+, +md5_password+, +originator+, +gateway+,
      # +charset+, and +type+.
      #
      # @return [Hash]
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

    # @return [Hash] the parameters that will be send to the gateway.
    attr_reader :params

    # Initializes a new Mollie::SMS instance.
    #
    # You can either specify the recipient’s telephone number and message
    # body here, or later on through the accessors for these attributes.
    #
    # @param [String] telephone_number the recipient’s telephone number.
    #
    # @param [String] body the message body.
    #
    # @param [Hash] extra_params optional parameters that are to be merged with
    #                            the {SMS.default_params default parameters}.
    def initialize(telephone_number = nil, body = nil, extra_params = {})
      @params = self.class.default_params.merge(extra_params)
      self.telephone_number = telephone_number if telephone_number
      self.body = body if body
    end

    # @return [String] the recipient’s telephone number.
    def telephone_number
      @params['recipients']
    end

    # Assigns the recipient’s telephone number.
    #
    # @param [String] telephone_number the recipient’s telephone number.
    # @return [String] the recipient’s telephone number.
    def telephone_number=(telephone_number)
      @params['recipients'] = telephone_number
    end

    # @return [String] the message body.
    def body
      @params['message']
    end

    # Assigns the message’s body.
    #
    # @param [String] body the message’s body.
    # @return [String] the message’s body.
    def body=(body)
      @params['message'] = body
    end

    # Compares whether or not this and the +other+ Mollie::SMS instance are
    # equal in recipient, body, and other parameters.
    #
    # @param [SMS] other the Mollie::SMS instance to compare against.
    # @return [true, false]
    def ==(other)
      other.is_a?(SMS) && other.params == params
    end

    # @return [String] a string representation of this instance.
    def to_s
      %{from: <#{params['originator']}> to: <#{telephone_number}> body: "#{body}"}
    end

    # @return [String] a `inspect' string representation of this instance.
    def inspect
      %{#<#{self.class.name} #{to_s}>}
    end

    # Posts the {#params parameters} to the gateway, through SSL.
    # 
    # The params are validated before attempting to post them.
    # @see #validate_params!
    #
    # @return [Response] a response object which encapsulates the result of the
    #                    request.
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

    # Posts the {#params parameters} through {#deliver}, but raises a
    # DeliveryFailure in case the request fails.
    #
    # This happens if an HTTP error occurs, or the gateway didn’t accept the
    # {#params parameters}.
    #
    # @return [Response] upon success, a response object which encapsulates the
    #                    result of the request.
    #
    # @raise [DeliveryFailure] an exception which encapsulates this {SMS SMS}
    #                          instance and the {Response} object.
    def deliver!
      response = deliver
      raise DeliveryFailure.new(self, response) unless response.success?
      response
    end

    # Checks if all {REQUIRED_PARAMS required parameters} are present and if
    # the {SMS.originator} is of the right size.
    #
    # The {SMS.originator} should be upto either fourteen numerical characters,
    # or eleven alphanumerical characters.
    #
    # @raise [ValidationError] if any of the validations fail.
    #
    # @return [nil]
    def validate_params!
      params.slice(*REQUIRED_PARAMS).each do |key, value|
        raise ValidationError, "The required parameter `#{key}' is missing." if value.blank?
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
