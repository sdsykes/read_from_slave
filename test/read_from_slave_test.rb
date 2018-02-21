require File.join(File.dirname(__FILE__), "helper")

ReadFromSlave::Test.setup

class ReadFromSlaveTest < ActiveSupport::TestCase
  test "slave connection should be different from normal connection" do
    assert_not_equal Course.connection_without_read_from_slave, Course.slave_connection(Course.primary_slave_config)
  end

  test "should be able to write and read from database" do
    Course.create(:name=>"Saw playing")
    x = Course.first
    assert_equal "Saw playing", x.name
  end

  test "should write to master" do
    Course.create(:name=>"Saw playing")
    assert_equal :master, Thread.current[:read_from_slave_uses]
  end

  test "should read from slave" do
    Course.create(:name=>"Saw playing")
    Course.first
    assert_equal :primary_slave, Thread.current[:read_from_slave_uses]
  end

  test "should reload from master" do
    Course.create(:name=>"Saw playing")
    x = Course.first
    x.reload
    assert_equal :master, Thread.current[:read_from_slave_uses]
  end

  test "should get new slave connection when calling establish_slave_connections" do
    conn = Course.slave_connection(Course.primary_slave_config)
    ActiveRecord::Base.establish_slave_connections
    assert_not_equal conn, Course.slave_connection(Course.primary_slave_config)
  end

  test "should not get new master connection when calling establish_slave_connections" do
    conn = Course.connection_without_read_from_slave
    ActiveRecord::Base.establish_slave_connections
    assert_equal conn, Course.connection_without_read_from_slave
  end

  test "count should use the slave" do
    count = Course.count
    Course.create(:name=>"Saw playing")
    assert_equal count + 1, Course.count
    assert_equal :primary_slave, Thread.current[:read_from_slave_uses]
  end

  test "primary_slave_config should return the right configuration" do
    assert_equal 'primary_slave', Course.primary_slave_config
  end

  test "slave is not used by default when all_reads_on_slave is false" do
    ReadFromSlave.all_reads_on_slave = false
    Course.create(:name=>"Saw playing")
    assert_equal :master, Thread.current[:read_from_slave_uses]
    Course.first
    assert_equal :master, Thread.current[:read_from_slave_uses]
  end

  test "correct slave is used with block" do
    Course.create(:name=>"Saw playing")
    Course.with_primary_slave do
      Course.first
      assert_equal :primary_slave, Thread.current[:read_from_slave_uses]
    end
    Course.with_slave_2 do
      Course.first
      assert_equal :slave_2, Thread.current[:read_from_slave_uses]
    end
  end

  test "on_master" do
    ReadFromSlave.on_master do
      Course.first
      assert_equal :master, Thread.current[:read_from_slave_uses]
    end
  end
end
