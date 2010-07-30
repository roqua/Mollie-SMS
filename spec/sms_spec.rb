require File.expand_path("../spec_helper", __FILE__)
require "mollie/sms"

Mollie::SMS.username = 'AstroRadio'
Mollie::SMS.password = 'secret'

describe "Mollie::SMS" do
  it "holds the gateway uri" do
    Mollie::SMS::GATEWAY_URI.should == URI.parse("http://www.mollie.nl/xml/sms")
  end

  it "holds the service username" do
    Mollie::SMS.username.should == 'AstroRadio'
  end

  it "holds the service password as a MD5 hashed version" do
    Mollie::SMS.password.should == Digest::MD5.hexdigest('secret')
  end

  it "returns the default charset" do
    Mollie::SMS.charset.should == 'UTF-8'
  end

  it "returns the default message type" do
    Mollie::SMS.type.should == 'normal'
  end

  it "holds a list of available gateways" do
    Mollie::SMS::GATEWAYS[:basic].should == '2'
    Mollie::SMS::GATEWAYS[:business].should == '4'
    Mollie::SMS::GATEWAYS[:business_plus].should == '1'
    Mollie::SMS::GATEWAYS[:landline].should == '8'
  end

  it "returns the default gateway to use" do
    Mollie::SMS.gateway.should == Mollie::SMS::GATEWAYS[:basic]
  end

  it "returns a hash of params for a request" do
    Mollie::SMS.request_params.should == {
      'username'     => 'AstroRadio',
      'md5_password' => Mollie::SMS.password,
      'gateway'      => '2',
      'charset'      => 'UTF-8',
      'type'         => 'normal'
    }
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
    @sms.request_params.should == params
  end
end

module Net
  class HTTP
    class << self
      attr_accessor :stubbed_response

      def reset!
        @posted = nil
        @stubbed_response = nil
      end

      def post_form(url, params)
        @posted = { 'url' => url, 'params' => params }
        @stubbed_response
      end

      def posted
        @posted ||= {}
      end
    end
  end
end

class ResponseStub
end

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
    @sms.deliver
    Net::HTTP.posted.should == {
      'url'    => Mollie::SMS::GATEWAY_URI,
      'params' => @sms.request_params
    }
  end

  it "returns a Mollie::SMS::Response object, with the Net::HTTP response" do
    Net::HTTP.stubbed_response = Net::HTTPOK.new('1.1', '200', 'OK')
    response = @sms.deliver
    response.should.be.instance_of Mollie::SMS::Response
    response.http_response.should == Net::HTTP.stubbed_response
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

describe "A Mollie::SMS::Response instance" do
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
