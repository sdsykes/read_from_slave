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
    
    def slave_connection
      (@slave_model || slave_model).connection_without_read_from_slave
    end

    def slave_model
      slave_model_name = "ReadFromSlaveFor_#{master_database_name}"
      @@slave_models ||= {}
      unless @@slave_models[slave_model_name]
        @@slave_models[slave_model_name] = eval %{
          class #{slave_model_name} < ActiveRecord::Base
            use_slave_db
          end
          #{slave_model_name}
        }
      end
      @slave_model = @@slave_models[slave_model_name]
    end

    def master_database_name
      connection_without_read_from_slave.instance_variable_get(:@config)[:database]
    end

    def use_slave_db
      conn_spec = configurations["slave_for_#{master_database_name}"]
      establish_connection(conn_spec) if conn_spec
    end
  end
end

ReadFromSlave.install!
