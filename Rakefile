desc "Run the specs"
task :spec do
  sh "ruby ./spec/sms_spec.rb"
  sh "ruby ./spec/test_helper_spec.rb"
  sh "ruby ./spec/functional_sms_deliver_spec.rb"
end

task :default => :spec

begin
  require 'rubygems'
  require 'jeweler'
  Jeweler::Tasks.new do |s|
    s.name     = "mollie-sms"
    s.homepage = "http://github.com/Fingertips/Mollie-SMS"
    s.email    = ["eloy@fngtps.com"]
    s.authors  = ["Eloy Duran"]
    s.summary  = s.description = "Send SMS text messages via the Mollie.nl SMS gateway."
    s.files   -= %w{ .gitignore TODO }
    s.extra_rdoc_files -= %w{ TODO }
    s.add_dependency('activesupport', '>= 2.3.8')
  end
rescue LoadError
end
