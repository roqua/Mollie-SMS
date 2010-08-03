case Rails.env
when "test"
  require 'mollie/sms/test_helper'
  require 'active_support/test_case'
  ActiveSupport::TestCase.send(:include, Mollie::SMS::TestHelper)
when "development"
  require 'mollie/sms/test_helper'
  class Mollie::SMS
    def deliver
     validate_params!
     Rails.logger.info "\n[!] SMS message sent #{to_s}\n\n"
     Mollie::SMS.stubbed_response
    end
  end
end
