require 'rubygems'

# specify rails version to test with here
#gem 'activerecord', '= 2.3.8'

require 'active_record'

ActiveRecord::Base.configurations = {
  'rfs' => {
    :adapter => 'sqlite3',
    :database => 'test_db',
    :timeout => 5000,
    :slaves => {
      :slave_1 => 'slave_for_test_db',
      :slave_2 => 'slave_2_for_test_db'
    }
  },
  'slave_for_test_db' => {
    :adapter => 'sqlite3',
    :database => 'test_db',
    :timeout => 5000
  },
  'slave_2_for_test_db' => {
    :adapter => 'sqlite3',
    :database => 'test_db',
    :timeout => 5000
  }
}

ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations['rfs'])

require File.join(File.dirname(__FILE__), '..', 'lib', 'read_from_slave')
