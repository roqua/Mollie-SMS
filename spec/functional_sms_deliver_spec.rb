require File.expand_path("../spec_helper", __FILE__)

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

describe "When sending a Mollie::SMS message" do
  before do
    @sms = Mollie::SMS.new
    @sms.telephone_number = '+31612345678'
    @sms.body = "The stars tell me you will have chicken noodle soup for breakfast."
  end

  after do
    Net::HTTP.reset!
  end

  it "posts the post body to the gateway" do
    @sms.stubs(:params).returns('a key' => 'a value')
    @sms.stubs(:validate_params!)
    @sms.deliver

    request, post = Net::HTTP.posted
    request.should.use_ssl
    request.host.should == Mollie::SMS::GATEWAY_URI.host
    request.port.should == Mollie::SMS::GATEWAY_URI.port
    post.path.should == Mollie::SMS::GATEWAY_URI.path
    post.body.should == "a+key=a+value"
  end

  it "returns a Mollie::SMS::Response object, with the Net::HTTP response" do
    Net::HTTP.stubbed_response = Net::HTTPOK.new('1.1', '200', 'OK')
    Net::HTTP.stubbed_response.stubs(:read_body).returns(SUCCESS_BODY)
    response = @sms.deliver!
    response.should.be.instance_of Mollie::SMS::Response
    response.http_response.should == Net::HTTP.stubbed_response
  end
end
