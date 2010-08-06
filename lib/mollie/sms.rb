require "digest/md5"
require "uri"
require "net/https"

begin
  require "rubygems"
rescue LoadError
end
require "active_support"

# The namespace for the Mollie.nl webservices.
#
# @see Mollie::SMS
module Mollie
  # A class that allows you to send SMS messages through the Mollie.nl SMS
  # webservice.
  #
  # = Configuration
  #
  # The minimum required settings are:
  # * {Mollie::SMS.username username}
  # * {Mollie::SMS.password password}
  # * {Mollie::SMS.originator originator}
  #
  # For example, a Rails initializer might look like:
  #
  #   module Mollie
  #     SMS.username   = 'Fingertips'
  #     SMS.password   = 'secret'
  #     SMS.originator = 'fngtps.nl'
  #   end
  #
  # = Examples
  #
  # @todo Add examples!
  #
  class SMS
    # A collection of exception classes raised by Mollie::SMS.
    module Exceptions
      # The base class for Mollie::SMS exceptions.
      class StandardError   < ::StandardError; end

      # The exception class which is used to indicate a validation error of one
      # of the {SMS#params parameters} that would be send to the gateway.
      class ValidationError < StandardError; end

      # The exception class which is used to indicate a delivery failure, when
      # the {SMS#deliver!} method is used and delivery fails.
      class DeliveryFailure < StandardError
        # @return [SMS] The Mollie::SMS instance.
        attr_reader :sms

        # @return [Response] The Mollie::SMS::Response instance.
        attr_reader :response

        # @param [SMS] sms The Mollie::SMS instance.
        # @param [Response] response The Mollie::SMS::Response instance.
        def initialize(sms, response)
          @sms, @response = sms, response
        end

        # @return [String] A string representation of the exception.
        def message
          "(#{@response.message}) #{@sms.to_s}"
        end
      end
    end

    # The SSL URI to which the parameters of a SMS are posted.
    GATEWAY_URI = URI.parse("https://secure.mollie.nl/xml/sms")

    # The possible values that indicate which {SMS.gateway= SMS gateway} should
    # be used.
    #
    # @see http://www.mollie.nl/sms-diensten/sms-gateway/gateways
    GATEWAYS = {
      'basic'     => '2',
      'business'  => '4',
      'business+' => '1',
      'landline'  => '8'
    }

    # A list of paramaters that *must* to be included in the
    # {SMS#params parameters} send to the gateway.
    REQUIRED_PARAMS = %w{ username md5_password originator gateway charset type recipients message }

    class << self
      # @return [String] Your username for the Mollie.nl SMS webservice.
      attr_accessor :username

      # @return [String] A MD5 hashed version of your password for the
      #                  Mollie.nl SMS webservice.
      attr_reader :password
      def password=(password)
        @password = Digest::MD5.hexdigest(password)
      end

      # The number, or display name, that will be used to indicate the
      # originator of a message.
      #
      # It should be upto either fourteen numerical characters, or eleven
      # alphanumerical characters.
      #
      # @see SMS#validate_params!
      #
      # @return [String] The originator
      attr_accessor :originator

      # @return [String] A character set name, describing the message’s body
      #                  encoding. Defaults to ‘UTF-8’.
      attr_accessor :charset

      # The type of messages that will be send. Possible values are:
      # * normal
      # * wappush
      # * vcard
      # * flash
      # * binary
      # * long
      #
      # Defaults to ‘normal’
      #
      # @return [String] The message type.
      attr_accessor :type

      # The gateway that should be used to send messages. Possible values are:
      # * {GATEWAYS GATEWAYS['basic']}
      # * {GATEWAYS GATEWAYS['business']}
      # * {GATEWAYS GATEWAYS['business+']}
      # * {GATEWAYS GATEWAYS['landline']}
      #
      # Defaults to ‘basic’.
      #
      # @see http://www.mollie.nl/sms-diensten/sms-gateway/gateways
      #
      # @return [String] The gateway ID.
      attr_accessor :gateway

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

    # @return [Hash] The parameters that will be send to the gateway.
    attr_reader :params

    # Initializes a new Mollie::SMS instance.
    #
    # You can either specify the recipient’s telephone number and message
    # body here, or later on through the accessors for these attributes.
    #
    # @param [String] telephone_number The recipient’s telephone number.
    #
    # @param [String] body The message body.
    #
    # @param [Hash] extra_params Optional parameters that are to be merged with
    #                            the {SMS.default_params default parameters}.
    def initialize(telephone_number = nil, body = nil, extra_params = {})
      @params = self.class.default_params.merge(extra_params)
      self.telephone_number = telephone_number if telephone_number
      self.body = body if body
    end

    # @return [String] The recipient’s telephone number.
    def telephone_number
      @params['recipients']
    end

    # Assigns the recipient’s telephone number.
    #
    # @param [String] telephone_number The recipient’s telephone number.
    # @return [String] The recipient’s telephone number.
    def telephone_number=(telephone_number)
      @params['recipients'] = telephone_number
    end

    # @return [String] The message body.
    def body
      @params['message']
    end

    # Assigns the message’s body.
    #
    # @param [String] body The message’s body.
    # @return [String] The message’s body.
    def body=(body)
      @params['message'] = body
    end

    # Compares whether or not this and the +other+ Mollie::SMS instance are
    # equal in recipient, body, and other parameters.
    #
    # @param [SMS] other The Mollie::SMS instance to compare against.
    # @return [Boolean]
    def ==(other)
      other.is_a?(SMS) && other.params == params
    end

    # @return [String] A string representation of this instance.
    def to_s
      %{from: <#{params['originator']}> to: <#{telephone_number}> body: "#{body}"}
    end

    # @return [String] A `inspect' string representation of this instance.
    def inspect
      %{#<#{self.class.name} #{to_s}>}
    end

    # Posts the {#params parameters} to the gateway, through SSL.
    # 
    # The params are validated before attempting to post them.
    # @see #validate_params!
    #
    # @return [Response] A response object which encapsulates the result of the
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
    # @return [Response] Upon success, a response object which encapsulates the
    #                    result of the request.
    #
    # @raise [DeliveryFailure] An exception which encapsulates this {SMS SMS}
    #                          instance and the {Response} object.
    def deliver!
      response = deliver
      raise DeliveryFailure.new(self, response) unless response.success?
      response
    end

    # Checks if all {REQUIRED_PARAMS required parameters} are present and if
    # the {SMS.originator} is of the right size.
    #
    # @see SMS.originator
    #
    # @raise [ValidationError] If any of the validations fail.
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

    # This class encapsulates the HTTP response and the response from the
    # gateway. Put shortly, instances of this class return whether or not a SMS
    # message has been delivered.
    class Response
      # @return [Net::HTTPResponse] The raw HTTP response object.
      attr_reader :http_response

      # Initializes a new Mollie::SMS::Response instance.
      #
      # @param [Net::HTTPResponse] http_response The HTTP response object.
      def initialize(http_response)
        @http_response = http_response
      end

      # @return [Hash] The response parameters from the gateway. Or an empty
      #                Hash if a HTTP error occurred.
      def params
        @params ||= http_failure? ? {} : Hash.from_xml(@http_response.read_body)['response']['item']
      end

      # Upon success, returns the result code from the gateway. Otherwise the
      # HTTP response code.
      #
      # The possible gateway result codes are:
      # * 10 - message sent
      # * 20 - no ‘username’
      # * 21 - no ‘password’
      # * 22 - no, or incorrect, ‘originator’
      # * 23 - no ‘recipients’
      # * 24 - no ‘message’
      # * 25 - incorrect ‘recipients’
      # * 26 - incorrect ‘originator’
      # * 27 - incorrect ‘message’
      # * 28 - charset failure
      # * 29 - parameter failure
      # * 30 - incorrect ‘username’ or ‘password’
      # * 31 - not enough credits to send message
      # * 38 - binary UDH parameter misformed
      # * 39 - ‘deliverydate’ format is not correct
      # * 98 - gateway unreachable
      # * 99 - unknown error
      #
      # @return [Integer] The result code from the gateway or HTTP response
      #                   code.
      def result_code
        (http_failure? ? @http_response.code : params['resultcode']).to_i
      end

      # @return [String] The message from the gateway, or the HTTP message in
      #                  case of a HTTP error.
      #
      # @see #result_code #result_code for a list of possible messages.
      def message
        http_failure? ? "[HTTP: #{@http_response.code}] #{@http_response.message}" : params['resultmessage']
      end

      # @return [Boolean] Whether or not the SMS message has been delivered.
      def success?
        !http_failure? && params['success'] == 'true'
      end

      # @return [Boolean] Whether or not the HTTP request was a success.
      def http_failure?
        !@http_response.is_a?(Net::HTTPSuccess)
      end

      # @return [String] A `inspect' string representation of this instance.
      def inspect
        "#<#{self.class.name} #{ success? ? 'succeeded' : 'failed' } (#{result_code}) `#{message}'>"
      end
    end
  end
end
