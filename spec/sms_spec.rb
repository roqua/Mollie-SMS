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
    def self.reset!
      @posted = {}
    end

    def self.post_form(url, params)
      @posted = { 'url' => url, 'params' => params }
    end

    def self.posted
      @posted ||= {}
    end
  end
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
end
