require File.expand_path("../spec_helper", __FILE__)
require "mollie/sms/test_helper"

describe "Mollie::SMS ext" do
  before do
    Mollie::SMS.reset!
    @sms = Mollie::SMS.new("+31612345678", "Future is coming.")
  end

  it "stubs any next delivery to be successful" do
    Mollie::SMS.success!
    @sms.deliver.should.be.success
  end

  it "stubs any next delivery to fail at the gateway" do
    Mollie::SMS.gateway_failure!
    response = @sms.deliver
    response.should.not.be.success
    response.should.not.be.http_failure
  end

  it "stubs any next delivery to fail at HTTP level" do
    Mollie::SMS.http_failure!
    response = @sms.deliver
    response.should.not.be.success
    response.should.be.http_failure
  end

  it "returns the stubbed response" do
    @sms.deliver.should == Mollie::SMS.stubbed_response
    @sms.deliver!.should == Mollie::SMS.stubbed_response
  end

  it "adds sms instance to a global array instead of actually delivering" do
    @sms.deliver
    @sms.deliver!
    Mollie::SMS.deliveries.last(2).should == [@sms, @sms]
  end

  it "empties the deliveries array and stubs a succeeded response" do
    @sms.deliver!
    Mollie::SMS.reset!
    Mollie::SMS.deliveries.should.be.empty
  end
end

describe "Mollie::SMS::TestHelper::Assertions" do
  extend Mollie::SMS::TestHelper::Assertions

  before do
    Mollie::SMS.reset!
    @sms = Mollie::SMS.new("+31612345678", "Future is coming.")
    @result = @message = nil
  end

  def assert(result, message)
    @result, @message = result, message
  end

  it "asserts that an email is sent while executing the block" do
    assert_sms_messages(2) { @sms.deliver; @sms.deliver }
    @result.should == true
  end

  it "fails if not the given amount of messages are sent" do
    assert_sms_messages(2) { @sms.deliver }
    @result.should == false
    @message.should == "expected `2' SMS messages to be sent, actually sent `1'"
  end

  it "asserts that no emails were sent while executing the block" do
    assert_no_sms_messages { }
    @result.should == true
  end

  it "fails if messages are actually sent" do
    assert_no_sms_messages { @sms.deliver }
    @result.should == false
    @message.should == "expected `0' SMS messages to be sent, actually sent `1'"
  end
end
