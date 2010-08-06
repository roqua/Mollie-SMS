module Mollie
  class SMS
    # A collection of helpers for testing the delivery of SMS messages.
    #
    # This includes:
    # * a couple of Test::Unit {Mollie::SMS::TestHelper::Assertions assertions}
    # * {Mollie::SMS::TestHelper::SMSExt Mollie::SMS} class extensions and
    #   overrides
    module TestHelper
      SUCCESS_BODY = %{
<?xml version="1.0" ?>
<response>
    <item type="sms">
        <recipients>1</recipients>
        <success>true</success>
        <resultcode>10</resultcode>
        <resultmessage>Message successfully sent.</resultmessage>
    </item>
</response>}

      FAILURE_BODY = %{
<?xml version="1.0"?>
<response>
  <item type="sms">
    <recipients>1</recipients>
    <success>false</success>
    <resultcode>20</resultcode>
    <resultmessage>No username given.</resultmessage>
  </item>
</response>}

      # A couple of Test::Unit assertions, to test the amount of sent messages.
      #
      # This module is automatically mixed into the Test::Unit::TestCase class,
      # if it’s defined at load time.
      module Assertions
        # Asserts that a specific number of SMS messages have been sent, for the
        # duration of the given block.
        #
        #   def test_invitation_message_is_sent
        #     assert_sms_messages(1) do
        #       Account.create(:telephone_number => "+31621212121")
        #     end
        #   end
        #
        # @yield The context that will be used to check the number of sent
        #        messages.
        #
        # @return [nil]
        #
        # @see Mollie::SMS::TestHelper::SMSExt::ClassMethods#deliveries
        #      Mollie::SMS.deliveries
        def assert_sms_messages(number_of_messages)
          before = Mollie::SMS.deliveries.length
          yield
          diff = Mollie::SMS.deliveries.length - before
          assert(diff == number_of_messages, "expected `#{number_of_messages}' SMS messages to be sent, actually sent `#{diff}'")
        end

        # Asserts that *no* SMS messages have been sent, for the duration of the
        # given block.
        #
        #   def test_no_invitation_message_is_sent_when_account_is_invalid
        #     assert_no_sms_messages do
        #       Account.create(:telephone_number => "invalid")
        #     end
        #   end
        #
        # @yield The context that will be used to check the number of sent
        #        messages.
        #
        # @return [nil]
        #
        # @see Mollie::SMS::TestHelper::SMSExt::ClassMethods#deliveries
        #      Mollie::SMS.deliveries
        def assert_no_sms_messages
          assert_sms_messages(0) { yield }
        end
      end

      # Extensions and overrides of the Mollie::SMS class for testing purposes.
      #
      # The class method extensions are defined on the
      # {Mollie::SMS::TestHelper::SMSExt::ClassMethods ClassMethods} module.
      module SMSExt
        # @private
        def self.included(klass)
          klass.undef_method :deliver
          klass.extend ClassMethods
        end

        # Overrides the normal {Mollie::SMS#deliver deliver} method to *never*
        # make an actual request.
        #
        # Instead, the SMS message, that’s to be delivered, is added to the
        # {Mollie::SMS::TestHelper::SMSExt::ClassMethods#deliveries
        # Mollie::SMS.deliveries} list for later inspection.
        #
        # The parameters are still validated.
        #
        # @return [Response] The stubbed Response instance.
        #
        # @see Mollie::SMS::TestHelper::SMSExt::ClassMethods#stubbed_response
        #      Mollie::SMS.stubbed_response
        def deliver
          validate_params!
          self.class.deliveries << self
          self.class.stubbed_response
        end

        module ClassMethods
          # @return [Array<Mollie::SMS>] A list of sent SMS messages.
          #
          # @see Mollie::SMS::TestHelper::SMSExt#deliver
          #      Mollie::SMS#deliver
          def deliveries
            @deliveries ||= []
          end

          # Clears the {#deliveries deliveries} list and stubs a {#success!
          # ‘success’} Response instance.
          #
          # @return [Response] The stubbed ‘success’ Response instance.
          def reset!
            @deliveries = []
            success!
          end

          # Stubs a ‘success’ Response instance.
          #
          # This means that any following calls to {Mollie::SMS#deliver} will
          # succeed and return the stubbed ‘success’ Response instance.
          #
          #   Mollie::SMS.success!
          #   response = Mollie::SMS.new(number, body).deliver
          #   response.success? # => true
          #   response.result_code # => 10
          #   response.message # => "Message successfully sent."
          #
          # @return [Response] The stubbed ‘success’ Response instance.
          def success!
            http_response = Net::HTTPOK.new('1.1', '200', 'OK')
            http_response.add_field('Content-type', 'application/xml')
            # @private
            def http_response.read_body; TestHelper::SUCCESS_BODY; end
            @stubbed_response = Mollie::SMS::Response.new(http_response)
          end

          # Stubs a ‘gateway failure’ Response instance.
          #
          # This means that any following calls to {Mollie::SMS#deliver} will
          # fail at the gateway and return the stubbed ‘gateway failure’
          # Response instance.
          #
          #   Mollie::SMS.gateway_failure!
          #   response = Mollie::SMS.new(number, body).deliver
          #   response.success? # => false
          #   response.result_code # => 20
          #   response.message # => "No username given."
          #
          # @return [Response] The stubbed ‘gateway failure’ Response
          #                    instance.
          def gateway_failure!
            http_response = Net::HTTPOK.new('1.1', '200', 'OK')
            http_response.add_field('Content-type', 'application/xml')
            # @private
            def http_response.read_body; TestHelper::FAILURE_BODY; end
            @stubbed_response = Mollie::SMS::Response.new(http_response)
          end

          # Stubs a ‘HTTP failure’ Response instance.
          #
          # This means that any following calls to {Mollie::SMS#deliver} will
          # fail at the HTTP level and return the stubbed ‘HTTP failure’
          # Response instance.
          #
          #   Mollie::SMS.http_failure!
          #   response = Mollie::SMS.new(number, body).deliver
          #   response.success? # => false
          #   response.result_code # => 400
          #   response.message # => "[HTTP: 400] Bad request"
          #
          # @return [Response] The stubbed ‘HTTP failure’ Response
          #                    instance.
          def http_failure!
            @stubbed_response = Mollie::SMS::Response.new(Net::HTTPBadRequest.new('1.1', '400', 'Bad request'))
          end

          # @return [Response] The stubbed Response instance that will be
          #                    returned for all requests from
          #                    {Mollie::SMS#deliver}.
          def stubbed_response
            @stubbed_response || success!
          end
        end
      end
    end
  end
end

if defined?(Test::Unit)
  Test::Unit::TestCase.send(:include, Mollie::SMS::TestHelper::Assertions)
end
Mollie::SMS.send(:include, Mollie::SMS::TestHelper::SMSExt)
