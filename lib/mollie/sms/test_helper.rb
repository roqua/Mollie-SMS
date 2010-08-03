module Mollie
  class SMS
    def self.deliveries
      @deliveries ||= []
    end

    def self.reset!
      @deliveries = []
      success!
    end

    def self.success!
      http_response = Net::HTTPOK.new('1.1', '200', 'OK')
      http_response.add_field('Content-type', 'application/xml')
      def http_response.read_body; TestHelper::SUCCESS_BODY; end
      @stubbed_response = Mollie::SMS::Response.new(http_response)
    end

    def self.gateway_failure!
      http_response = Net::HTTPOK.new('1.1', '200', 'OK')
      http_response.add_field('Content-type', 'application/xml')
      def http_response.read_body; TestHelper::FAILURE_BODY; end
      @stubbed_response = Mollie::SMS::Response.new(http_response)
    end

    def self.http_failure!
      @stubbed_response = Mollie::SMS::Response.new(Net::HTTPBadRequest.new('1.1', '400', 'Bad request'))
    end

    def self.stubbed_response
      @stubbed_response || success!
    end

    def deliver
      validate_params!
      self.class.deliveries << self
      self.class.stubbed_response
    end

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

      def assert_sms_messages(number_of_messages)
        before = Mollie::SMS.deliveries.length
        yield
        diff = Mollie::SMS.deliveries.length - before
        assert(diff == number_of_messages, "expected `#{number_of_messages}' SMS messages to be sent, actually sent `#{diff}'")
      end

      def assert_no_sms_messages
        assert_sms_messages(0) { yield }
      end
    end
  end
end

