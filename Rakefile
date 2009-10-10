require 'rake'
require 'rake/testtask'
require 'test/helper'

task :default => [:test_read_from_slave]

task :test => :default

Rake::TestTask.new(:test_with_active_record) do |t|
  t.libs << ReadFromSlave::ActiveRecordTest::AR_TEST_SUITE
  t.libs << ReadFromSlave::ActiveRecordTest.connection
  t.test_files = ReadFromSlave::ActiveRecordTest.test_files
  t.ruby_opts = ["-r #{File.join(File.dirname(__FILE__), 'test', 'active_record_setup')}"]
  t.verbose = true
end

Rake::TestTask.new(:test_read_from_slave) do |t|
  t.libs << 'lib'
  t.test_files = ReadFromSlave::Test.test_files
  t.verbose = true
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |s|
    s.name = "read_from_slave"
    s.summary = "Read_from_slave - Utilise your slave databases with rails"
    s.email = "sdsykes@gmail.com"
    s.homepage = "http://github.com/sdsykes/read_from_slave"
    s.description = "Read_from_slave for Rails enables database reads from a slave database, while writes continue to go to the master"
    s.authors = ["Stephen Sykes"]
    s.files = FileList["[A-Z]*", "{lib,test}/**/*"]
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://
gems.github.com"
end
