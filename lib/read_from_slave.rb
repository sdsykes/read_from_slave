# Read_from_slave for Rails enables database reads from a slave database, while writes continue 
# to go to the master
# To use read_from_slave you must install the gem, configure the gem in your environment file,
# and setup your database.yml file with an entry for your slave database.
#
# === Configuration
# In config/environments/production.rb (for instance)
#
#   config.gem "sdsykes-read_from_slave", :lib=>"read_from_slave"
#
# In config/database.yml  
#
#   production:
#     adapter: mysql
#     database: mydatabase
#     username: myuser
#     password: mypassword
#     host: my.main.database.server.com
#     port: 3306
#
#   slave_for_mydatabase:
#     adapter: mysql
#     database: mydatabase
#     username: myuser
#     password: mypassword
#     socket: /var/lib/mysql/mysql.sock
#
# Note that if you have multiple databases you can also configure multiple slaves - use the
# database name after slave_for_ in the configuration.
#
# === References
# * "Masochism":http://github.com/technoweenie/masochism/tree/master
# ** not thread safe
# ** won't work with apps that talk to multiple (master) databases
# * "Acts as readonlyable":http://rubyforge.org/projects/acts-as-with-ro/
# ** old, not suitable for Rails 2.x
#
module ReadFromSlave
  class << self
    def install!
      ActiveRecord::Base.extend(SingletonMethods)
      ActiveRecord::Base.class_eval do
        class << self
          alias_method_chain :find_by_sql, :read_from_slave
          alias_method_chain :connection, :read_from_slave
        end
      end
    end
  end
  
  module SingletonMethods
    def find_by_sql_with_read_from_slave(sql)
      Thread.current[:read_from_slave] = true
      find_by_sql_without_read_from_slave(sql)
    ensure
      if Thread.current[:read_from_slave_connection]
        @slave_model.connection_pool.checkin Thread.current[:read_from_slave_connection]
        Thread.current[:read_from_slave_connection] = false
      end
      Thread.current[:read_from_slave] = false
    end

    def connection_with_read_from_slave
      normal_connection = connection_without_read_from_slave
      if Thread.current[:read_from_slave] && normal_connection.open_transactions == 0
        slave_connection
      else
        normal_connection
      end
    end
    
    # Returns a connection to the slave database, or to the regular database if
    # no slave is configured
    #
    def slave_connection
      Thread.current[:read_from_slave_connection] ||= (@slave_model || slave_model).connection_pool.checkout
    end

    # Returns an AR model class that has a connection to the appropriate slave db
    #
    def slave_model
      slave_model_name = "ReadFromSlaveFor_#{master_database_name}"
      @@slave_models ||= {}
      unless @@slave_models[slave_model_name]
        @@slave_models[slave_model_name] = eval %{
          class #{slave_model_name} < ActiveRecord::Base
            self.abstract_class = true
            use_slave_db_for('#{master_database_name}')
          end
          #{slave_model_name}
        }
      end
      @slave_model = @@slave_models[slave_model_name]
    end

    # Returns the name of the database in use, as given in the database.yml file
    #
    def master_database_name
      connection_without_read_from_slave.instance_variable_get(:@config)[:database]
    end

    # Establishes a connection to the slave database that is configured for
    # the database name provided
    #
    def use_slave_db_for(master)
      conn_spec = configurations["slave_for_#{master}"]
      establish_connection(conn_spec) if conn_spec
    end
  end
end

ReadFromSlave.install!
