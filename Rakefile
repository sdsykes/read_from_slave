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
