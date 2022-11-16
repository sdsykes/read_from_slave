# Read_from_slave for Rails enables database reads from one or more slave databases, while writes continue
# to go to the master
# To use read_from_slave you must install the gem, configure the gem in your environment file,
# and setup your database.yml file with an entry for your slave database.
#
#   gem install read_from_slave
#
# Read_from_slave is compatible with Rails 2.2.x and Rails 3
#
# === Configuration
# In config/environments/production.rb (for instance)
#
#   config.gem "read_from_slave"
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
#     slaves:
#       slave_1:  slave_for_reads
#       slave_2:  slave_for_reporting
#
#   slave_for_reads:
#     adapter: mysql
#     database: mydatabase
#     username: myuser
#     password: mypassword
#     socket: /var/lib/mysql/mysql.sock
#
#   slave_for_reporting:
#     adapter: mysql
#     database: mydatabase
#     username: myuser
#     password: mypassword
#     host: my.slave.database.server.com
#
# Note that if you have multiple databases you can also configure multiple slaves.
#
# === References
# * "Masochism":http://github.com/technoweenie/masochism/tree/master
# ** not thread safe
# ** won't work with apps that talk to multiple (master) databases
# * "Acts as readonlyable":http://rubyforge.org/projects/acts-as-with-ro/
# ** old, not suitable for Rails 2.x
# * "master_slave_adapter":http://github.com/mauricio/master_slave_adapter/tree/master
# ** similar to read_from_slave, but adapter based approach
# * "multi_db":http://github.com/schoefmax/multi_db/tree/master
# ** another one, proxy connection approach
# ** looks like it won't work with apps that talk to multiple (master) databases
# ** more complex than read_from_slave
#
module ReadFromSlave
  class << self
    def install!
      base = ActiveRecord::Base
      base.send(:include, InstanceMethods)
      base.send(:alias_method, :reload_without_read_from_slave, :reload)
      base.send(:alias_method, :reload, :reload_with_read_from_slave)
      base.extend(ClassMethods)
      base.class_eval do
        class << self
          alias_method :find_by_sql_without_read_from_slave, :find_by_sql
          alias_method :find_by_sql, :find_by_sql_with_read_from_slave
          alias_method :connection_without_read_from_slave, :connection
          alias_method :connection, :connection_with_read_from_slave
        end
      end

      begin
        calculation_base = ActiveRecord::Relation  # rails 3
        calculation_base.send(:include, CalculationMethod)
        calculation_base.send(:alias_method, :calculate_without_read_from_slave, :calculate)
        calculation_base.send(:alias_method, :calculate, :calculate_with_read_from_slave)
      rescue NameError  # rails 2
        base.extend(CalculationMethod)
        base.class_eval do
          class << self
            alias_method :calculate_without_read_from_slave, :calculate
            alias_method :calculate, :calculate_with_read_from_slave
          end
        end
      end
    end

    def install_with_methods!
      ActiveRecord::Base.connection.instance_variable_get(:@config)[:slaves].each_key do |slave_name|
        ActiveRecord::Base.class_eval <<-EOM
          def self.with_#{slave_name}(&block)
            Thread.current[:with_#{slave_name}_count] ||= 0
            Thread.current[:with_#{slave_name}_count] += 1
            yield
          ensure
            Thread.current[:with_#{slave_name}_count] -= 1
          end
        EOM
      end if ActiveRecord::Base.connection.instance_variable_get(:@config)[:slaves]
    end

    def default_to_master!
      base = ActiveRecord::Base
      base.class_eval do
        class << self
          alias_method :connection_without_slave_db_scope, :connection unless ReadFromSlave.all_reads_on_slave
          alias_method :connection, :connection_with_slave_db_scope unless ReadFromSlave.all_reads_on_slave
        end
      end
    end

    @@all_reads_on_slave = true
    def all_reads_on_slave=(all_reads)
      @@all_reads_on_slave = all_reads
      default_to_master!
    end

    def all_reads_on_slave
      @@all_reads_on_slave
    end

    def on_master
      Thread.current[:on_master] = true
      yield if block_given?
    rescue
      raise
    ensure
      Thread.current[:on_master] = false
    end
  end

  module InstanceMethods
    def reload_with_read_from_slave(options = nil)
      Thread.current[:read_from_slave] = :reload
      reload_without_read_from_slave(options)
    end
  end

  module ClassMethods

    @@slave_models = {}

    def find_by_sql_with_read_from_slave(*find_args)
      reload = (:reload  == Thread.current[:read_from_slave])
      on_master = Thread.current[:on_master]
      Thread.current[:read_from_slave] = !(reload || on_master)
      find_by_sql_without_read_from_slave(*find_args)
    ensure
      Thread.current[:read_from_slave] = false
    end

    def connection_with_slave_db_scope
      slaves.each_key do |slave_name|
        if Thread.current[:"with_#{slave_name}_count"].to_i > 0
          return connection_without_slave_db_scope
        end
      end
      connection_without_read_from_slave
    end

    def connection_with_read_from_slave
      normal_connection = connection_without_read_from_slave
      if Thread.current[:read_from_slave] && normal_connection.open_transactions == 0
        slaves.each do |slave_name, slave_config|
          if Thread.current[:"with_#{slave_name}_count"].to_i > 0
            Thread.current[:read_from_slave_uses] = slave_name.to_sym  # for testing use
            return slave_connection(slave_config)
          end
        end
        # If we're not in a with_slave block, default to the primary slave
        Thread.current[:read_from_slave_uses] = primary_slave_name  # for testing use
        return slave_connection(primary_slave_config)
      else
        Thread.current[:read_from_slave_uses] = :master
        return normal_connection
      end
    end

    # Returns a connection to the slave database, or to the regular database if
    # no slave is configured
    #
    def slave_connection(slave_config)
      @slave_model ||= {}
      (@slave_model[slave_config] || slave_model(slave_config)).connection_without_read_from_slave
    end


    # Returns an AR model class that has a connection to the appropriate slave db
    #
    def slave_model(slave_config)
      if slave_config_for(slave_config)
        unless @@slave_models[slave_config]
          slave_model_name = "ReadFromSlaveFor_#{slave_config}"
          @@slave_models[slave_config] = eval %{
            class #{slave_model_name} < ActiveRecord::Base
              self.abstract_class = true
              establish_slave_connection_for('#{slave_config}')
            end
            #{slave_model_name}
          }
        end
        @slave_model[slave_config] = @@slave_models[slave_config]
      else
        @slave_model[slave_config] = self
      end
    end

    #    # Returns the name of the database in use, as given in the database.yml file
    #    #
    #    def master_database_name
    #      connection_without_read_from_slave.instance_variable_get(:@config)[:database]
    #    end

    # Returns a hash of the slave databases, as given in the database.yml file
    def slaves
      connection_without_read_from_slave.instance_variable_get(:@config)[:slaves] || {}
    end

    # Returns the first slave defined in database.yml which will be used by default for reads
    def primary_slave_config
      slaves.symbolize_keys[primary_slave_name]
    end

    # Returns the first slave defined in database.yml which will be used by default for reads
    def primary_slave_name
      :primary_slave
    end

    # Returns the config for the associated slave database for this master,
    # as given in the database.yml file
    #
    def slave_config_for(slave_config)
      configurations[slave_config]
    end

    # Establishes a connection to the slave database that is configured for
    # the database name provided
    #
    def establish_slave_connection_for(slave_config)
      conn_spec = slave_config_for(slave_config)
      establish_connection(conn_spec) if conn_spec
    end

    # Re-establishes connections to all the slave databases that
    # have been used so far.  Use this in your
    # PhusionPassenger.on_event(:starting_worker_process) block if required.
    #
    def establish_slave_connections
      @@slave_models.each do |slave_config, model|
        model.establish_slave_connection_for(slave_config)
      end
    end
  end

  module CalculationMethod
    def calculate_with_read_from_slave(*args)
      Thread.current[:read_from_slave] = true
      calculate_without_read_from_slave(*args)
    ensure
      Thread.current[:read_from_slave] = false
    end
  end
end

ReadFromSlave.install!
if defined? ::Rails::Railtie
  require 'read_from_slave/railtie'
else
  ReadFromSlave.install_with_methods!
end
