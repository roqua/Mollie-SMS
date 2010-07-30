require "digest/md5"
require "uri"

module Mollie
  class SMS
    GATEWAYS = {
      :basic         => 2,
      :business      => 4,
      :business_plus => 1,
      :landline      => 8
    }

    class << self
      attr_accessor :username, :password, :charset, :type, :gateway

      def password=(password)
        @password = Digest::MD5.hexdigest(password)
      end

      def request_params
        {
          :username     => @username,
          :md5_password => @password,
          :gateway      => @gateway,
          :charset      => @charset,
          :type         => :normal
        }
      end
    end

    self.charset = 'UTF-8'
    self.type    = :normal
    self.gateway = GATEWAYS[:basic]    

    attr_accessor :telephone_number, :body

    def request_params
      self.class.request_params.merge(:recipients => @telephone_number, :message => @body)
    end

    def post_body
      request_params.map do |key, value|
        "#{URI.escape(key.to_s)}=#{URI.escape(value.to_s)}"
      end.join('&')
    end
  end
end
