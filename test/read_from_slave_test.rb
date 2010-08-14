require File.join(File.dirname(__FILE__), "helper")

ReadFromSlave::Test.setup

class ReadFromSlaveTest < ActiveSupport::TestCase
  test "slave connection should be different from normal connection" do
    assert_not_equal Course.connection_without_read_from_slave, Course.slave_connection
  end

  test "should be able to write and read from database" do
    Course.create(:name=>"Saw playing")
    x = Course.find(:first)
    assert_equal "Saw playing", x.name
  end

  test "should write to master" do
    Course.create(:name=>"Saw playing")
    assert_equal :master, Thread.current[:read_from_slave_uses]
  end

  test "should read from slave" do
    Course.create(:name=>"Saw playing")
    x = Course.find(:first)
    assert_equal :slave, Thread.current[:read_from_slave_uses]
  end

  test "should reload from master" do
    Course.create(:name=>"Saw playing")
    x = Course.find(:first)
    x.reload
    assert_equal :master, Thread.current[:read_from_slave_uses]
  end

  test "should get new slave connection when calling establish_slave_connections" do
    conn = Course.slave_connection
    ActiveRecord::Base.establish_slave_connections
    assert_not_equal conn, Course.slave_connection
  end

  test "should not get new master connection when calling establish_slave_connections" do
    conn = Course.connection_without_read_from_slave
    ActiveRecord::Base.establish_slave_connections
    assert_equal conn, Course.connection_without_read_from_slave
  end
  
  test "count should use the slave" do
    Course.create(:name=>"Saw playing")
    assert_equal 1, Course.count
    assert_equal :slave, Thread.current[:read_from_slave_uses]
  end
end
