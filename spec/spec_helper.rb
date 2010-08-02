require "rubygems"
require "bacon"
require "mocha"

$:.unshift File.expand_path("../../lib", __FILE__)

Bacon.summary_on_exit

module Net
  class HTTP
    class << self
      attr_accessor :posted, :stubbed_response

      def reset!
        @posted = nil
        @stubbed_response = nil
      end
    end

    def host
      @address
    end

    def start
      yield self
    end

    def request(request)
      self.class.posted = [self, request]
      self.class.stubbed_response
    end
  end
end

class ResponseStub
end

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
