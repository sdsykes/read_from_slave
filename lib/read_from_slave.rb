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
# * "master_slave_adapter":http://github.com/mauricio/master_slave_adapter/tree/master
# ** similar to read_from_slave, but adapter based approach
#
module ReadFromSlave
  class << self
    def install!
      base = ActiveRecord::Base
      base.send(:include, InstanceMethods)
      base.alias_method_chain :reload, :read_from_slave
      base.extend(SingletonMethods)
      base.class_eval do
        class << self
          alias_method_chain :find_by_sql, :read_from_slave
          alias_method_chain :connection, :read_from_slave
        end
      end
    end
  end

  module InstanceMethods
    def reload_with_read_from_slave
      Thread.current[:read_from_slave] = :reload
      reload_without_read_from_slave
    end
  end

  module SingletonMethods

    @@slave_models = {}

    def find_by_sql_with_read_from_slave(sql)
      Thread.current[:read_from_slave] = (Thread.current[:read_from_slave] != :reload)
      find_by_sql_without_read_from_slave(sql)
    ensure
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
      (@slave_model || slave_model).connection_without_read_from_slave
    end


    # Returns an AR model class that has a connection to the appropriate slave db                   
    #                                                                                               
    def slave_model
      db_name = master_database_name
      unless @@slave_models[db_name]
        slave_model_name = "ReadFromSlaveFor_#{db_name}"
        @@slave_models[db_name] = eval %{
          class #{slave_model_name} < ActiveRecord::Base
            self.abstract_class = true
            establish_slave_connection_for('#{db_name}')
          end
          #{slave_model_name}
        }
      end
      @slave_model = @@slave_models[db_name]
    end

    # Returns the name of the database in use, as given in the database.yml file                    
    #                                                                                               
    def master_database_name
      connection_without_read_from_slave.instance_variable_get(:@config)[:database]
    end

    # Establishes a connection to the slave database that is configured for                         
    # the database name provided                                                                    
    #                                                                                               
    def establish_slave_connection_for(master)
      conn_spec = configurations["slave_for_#{master}"]
      establish_connection(conn_spec) if conn_spec
    end

    def establish_slave_connections
      @@slave_models.each do |db_name, model|
        model.establish_slave_connection_for(db_name)
      end
    end
  end
end

ReadFromSlave.install!
