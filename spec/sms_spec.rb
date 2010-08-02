require File.expand_path("../spec_helper", __FILE__)
require "mollie/sms"

Mollie::SMS.username = 'AstroRadio'
Mollie::SMS.password = 'secret'
Mollie::SMS.originator = 'Fingertips'

describe "Mollie::SMS" do
  it "holds the gateway uri" do
    Mollie::SMS::GATEWAY_URI.should == URI.parse("https://secure.mollie.nl/xml/sms")
  end

  it "holds the service username" do
    Mollie::SMS.username.should == 'AstroRadio'
  end

  it "holds the service password as a MD5 hashed version" do
    Mollie::SMS.password.should == Digest::MD5.hexdigest('secret')
  end

  it "holds the originator" do
    Mollie::SMS.originator.should == 'Fingertips'
  end

  it "returns the default charset" do
    Mollie::SMS.charset.should == 'UTF-8'
  end

  it "returns the default message type" do
    Mollie::SMS.type.should == 'normal'
  end

  it "holds a list of available gateways" do
    Mollie::SMS::GATEWAYS['basic'].should == '2'
    Mollie::SMS::GATEWAYS['business'].should == '4'
    Mollie::SMS::GATEWAYS['business+'].should == '1'
    Mollie::SMS::GATEWAYS['landline'].should == '8'
  end

  it "returns the default gateway to use" do
    Mollie::SMS.gateway.should == Mollie::SMS::GATEWAYS['basic']
  end

  it "returns a hash of params for a request" do
    Mollie::SMS.request_params.should == {
      'username'     => 'AstroRadio',
      'md5_password' => Digest::MD5.hexdigest('secret'),
      'originator'   => 'Fingertips',
      'gateway'      => '2',
      'charset'      => 'UTF-8',
      'type'         => 'normal'
    }
  end

  it "initializes, optionally, with a telephone number, body, and params" do
    sms1 = Mollie::SMS.new
    sms1.telephone_number = '+31612345678'
    sms1.body = "The stars tell me you will have chicken noodle soup for breakfast."

    sms2 = Mollie::SMS.new('+31612345678', "The stars tell me you will have chicken noodle soup for breakfast.", 'originator' => 'Eloy')
    sms2.params['originator'].should == 'Eloy'

    [sms1, sms2].each do |sms|
      sms.telephone_number.should == '+31612345678'
      sms.body.should == "The stars tell me you will have chicken noodle soup for breakfast."
    end
  end
end

describe "A Mollie::SMS instance" do
  before do
    @sms = Mollie::SMS.new
    @sms.telephone_number = '+31612345678'
    @sms.body = "The stars tell me you will have chicken noodle soup for breakfast."
  end

  it "returns the phone number" do
    @sms.telephone_number.should == '+31612345678'
  end

  it "returns the message body" do
    @sms.body.should == "The stars tell me you will have chicken noodle soup for breakfast."
  end

  it "returns the request params with all string keys and values" do
    params = Mollie::SMS.request_params.merge(
      'recipients' => '+31612345678',
      'message'    => "The stars tell me you will have chicken noodle soup for breakfast."
    )
    @sms.params.should == params
  end
end

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
    @sms.deliver

    request, post = Net::HTTP.posted
    request.should.use_ssl
    request.host.should == Mollie::SMS::GATEWAY_URI.host
    request.port.should == Mollie::SMS::GATEWAY_URI.port
    post.path.should == Mollie::SMS::GATEWAY_URI.path
    post.body.should == "a%20key=a%20value"
  end

  it "returns a Mollie::SMS::Response object, with the Net::HTTP response" do
    Net::HTTP.stubbed_response = Net::HTTPOK.new('1.1', '200', 'OK')
    Net::HTTP.stubbed_response.stubs(:read_body).returns(SUCCESS_BODY)
    response = @sms.deliver
    response.should.be.instance_of Mollie::SMS::Response
    response.http_response.should == Net::HTTP.stubbed_response
  end
end

describe "A Mollie::SMS::Response instance, for a succeeded request" do
  before do
    @http_response = Net::HTTPOK.new('1.1', '200', 'OK')
    @http_response.stubs(:read_body).returns(SUCCESS_BODY)
    @http_response.add_field('Content-type', 'application/xml')
    @response = Mollie::SMS::Response.new(@http_response)
  end

  it "returns the Net::HTTP response object" do
    @response.http_response.should == @http_response
  end

  it "returns the response body as a hash" do
    @response.params.should == Hash.from_xml(SUCCESS_BODY)['response']['item']
  end

  it "returns whether or not it was a success" do
    @response.should.be.success

    @response.stubs(:params).returns('success' => 'false')
    @response.should.not.be.success
  end

  it "returns the result code" do
    @response.result_code.should == 10
  end

  it "returns the message corresponding to the result code" do
    @response.message.should == "Message successfully sent."
  end
end

describe "A Mollie::SMS::Response instance, for a failed request" do
  before do
    @http_response = Net::HTTPBadRequest.new('1.1', '400', 'Bad request')
    @response = Mollie::SMS::Response.new(@http_response)
  end

  it "returns an empty hash as the params" do
    @response.params.should == {}
  end

  it "returns that the request was not a success" do
    @response.should.not.be.success
  end

  it "returns nil as the result_code" do
    @response.result_code.should == nil
  end

  it "returns nil as the message" do
    @response.message.should == nil
  end
end
