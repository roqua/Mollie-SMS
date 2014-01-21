require "rubygems"
require "bacon"
require "mocha/api"

Bacon.summary_on_exit

$:.unshift File.expand_path("../../lib", __FILE__)
require "mollie/sms"

Mollie::SMS.username = 'AstroRadio'
Mollie::SMS.password = 'secret'
Mollie::SMS.originator = 'Astro INC'
