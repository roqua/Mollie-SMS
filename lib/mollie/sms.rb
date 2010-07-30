require "digest/md5"

module Mollie
  class SMS
    GATEWAYS = {
      :basic         => 2,
      :business      => 4,
      :business_plus => 1,
      :landline      => 8
    }

    class << self
      attr_accessor :username, :password, :charset, :type, :return_charged_amount, :gateway

      def password=(password)
        @password = Digest::MD5.hexdigest(password)
      end

      def request_params
        params = {
          :username     => @username,
          :md5_password => @password,
          :gateway      => @gateway,
          :charset      => @charset,
          :type         => :normal
        }
        params[:return] = "charged" if @return_charged_amount
        params
      end
    end

    self.charset = 'UTF-8'
    self.type    = :normal
    self.gateway = GATEWAYS[:basic]    
    self.return_charged_amount = true

    attr_accessor :telephone_number, :body
  end
end
