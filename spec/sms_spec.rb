require File.expand_path("../spec_helper", __FILE__)
require "mollie/sms/test_helper"

describe "Mollie::SMS" do
  it "holds the gateway uri" do
    Mollie::SMS::GATEWAY_URI.should == URI.parse("https://api.messagebird.nl/xml/sms")
  end

  it "holds the service username" do
    Mollie::SMS.username.should == 'AstroRadio'
  end

  it "holds the service password as a MD5 hashed version" do
    Mollie::SMS.password.should == Digest::MD5.hexdigest('secret')
  end

  it "holds the originator" do
    Mollie::SMS.originator.should == 'Astro INC'
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

  it "returns a hash of default params for a request" do
    Mollie::SMS.default_params.should == {
      'username'     => 'AstroRadio',
      'md5_password' => Digest::MD5.hexdigest('secret'),
      'originator'   => 'Astro INC',
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
    params = Mollie::SMS.default_params.merge(
      'recipients' => '+31612345678',
      'message'    => "The stars tell me you will have chicken noodle soup for breakfast."
    )
    @sms.params.should == params
  end

  it "checks equality by comparing the params" do
    @sms.should == Mollie::SMS.new('+31612345678', "The stars tell me you will have chicken noodle soup for breakfast.")
    @sms.should.not == Mollie::SMS.new('+31612345678', "Different message")
    @sms.should.not == Mollie::SMS.new('+31612345678', "The stars tell me you will have chicken noodle soup for breakfast.", 'originator' => 'Some being')
  end

  it "returns a string representation of itself" do
    @sms.to_s.should == 'from: <Astro INC> to: <+31612345678> body: "The stars tell me you will have chicken noodle soup for breakfast."'
  end
end

describe "When sending a Mollie::SMS message" do
  before do
    @sms = Mollie::SMS.new
    @sms.telephone_number = '+31612345678'
    @sms.body = "The stars tell me you will have chicken noodle soup for breakfast."
  end

  it "raises a Mollie::SMS::DeliveryFailure exception when sending, through the #deliver! method, fails" do
    Mollie::SMS.gateway_failure!

    exception = nil
    begin
      @sms.deliver!
    rescue Mollie::SMS::Exceptions::DeliveryFailure => exception
    end

    exception.message.should == "(No username given.) #{@sms.to_s}"
  end
end

describe "A Mollie::SMS::Response instance, for a succeeded request" do
  before do
    @response = Mollie::SMS.success!
  end

  it "returns the Net::HTTP response object" do
    @response.http_response.should.is_a?(Net::HTTPSuccess)
  end

  it "returns the response body as a hash" do
    @response.params.should == Hash.from_xml(Mollie::SMS::TestHelper::SUCCESS_BODY)['response']['item']
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

describe "A Mollie::SMS::Response instance, for a request that failed at the gateway" do
  before do
    @response = Mollie::SMS.gateway_failure!
  end

  it "returns that the request was not a success" do
    @response.should.not.be.success
  end

  it "returns that this is a *not* HTTP failure" do
    @response.should.not.be.http_failure
  end

  it "returns the result_code" do
    @response.result_code.should == 20
  end

  it "returns the message corresponding to the result code" do
    @response.message.should == "No username given."
  end
end

describe "A Mollie::SMS::Response instance, for a failed HTTP request" do
  before do
    @response = Mollie::SMS.http_failure!
  end

  it "returns an empty hash as the params" do
    @response.params.should == {}
  end

  it "returns that the request was not a success" do
    @response.should.not.be.success
  end

  it "returns that this is a HTTP failure" do
    @response.should.be.http_failure
  end

  it "returns the HTTP response code as the result_code" do
    @response.result_code.should == 400
  end

  it "returns the HTTP error message as the message" do
    @response.message.should == "[HTTP: 400] Bad request"
  end
end

describe "Mollie::SMS, concerning validation" do
  before do
    @sms = Mollie::SMS.new
    @sms.telephone_number = '+31612345678'
    @sms.body = "The stars tell me you will have chicken noodle soup for breakfast."
  end

  it "accepts an originator of upto 14 numbers" do
    @sms.params['originator'] = "00000000001111"
    lambda { @sms.deliver }.should.not.raise
  end

  it "does not accept an originator string with more than 14 numbers" do
    @sms.params['originator'] = "000000000011112"
    lambda do
      @sms.deliver
    end.should.raise(Mollie::SMS::Exceptions::ValidationError, "Originator may have a maximimun of 14 numerical characters.")
  end

  it "accepts an originator of upto 11 alphanumerical characters" do
    @sms.params['originator'] = "0123456789A"
    lambda { @sms.deliver }.should.not.raise
  end

  it "does not accept an originator string with more than 11 alphanumerical characters" do
    @sms.params['originator'] = "0123456789AB"
    lambda do
      @sms.deliver
    end.should.raise(Mollie::SMS::Exceptions::ValidationError, "Originator may have a maximimun of 11 alphanumerical characters.")
  end
end
