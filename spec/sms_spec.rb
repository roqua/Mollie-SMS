require File.expand_path("../spec_helper", __FILE__)
require "mollie/sms"

Mollie::SMS.username = 'AstroRadio'
Mollie::SMS.password = 'secret'

describe "Mollie::SMS" do
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
    Mollie::SMS.type.should == :normal
  end

  it "holds a list of available gateways" do
    Mollie::SMS::GATEWAYS[:basic].should == 2
    Mollie::SMS::GATEWAYS[:business].should == 4
    Mollie::SMS::GATEWAYS[:business_plus].should == 1
    Mollie::SMS::GATEWAYS[:landline].should == 8
  end

  it "returns the default gateway to use" do
    Mollie::SMS.gateway.should == Mollie::SMS::GATEWAYS[:basic]
  end

  it "returns a hash of params for a request" do
    Mollie::SMS.request_params.should == {
      :username     => 'AstroRadio',
      :md5_password => Mollie::SMS.password,
      :gateway      => 2,
      :charset      => 'UTF-8',
      :type         => :normal
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

  it "returns the request params" do
    params = Mollie::SMS.request_params.merge(
      :recipients => '+31612345678',
      :message => "The stars tell me you will have chicken noodle soup for breakfast."
    )
    @sms.request_params.should == params
  end

  it "returns a string version of the request params" do
    def @sms.request_params
      [[:key, :value], ["another key", "another value"]]
    end
    @sms.post_body.should == "key=value&another%20key=another%20value"
  end
end
