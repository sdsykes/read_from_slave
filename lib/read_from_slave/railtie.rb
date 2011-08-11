require 'read_from_slave'
require 'rails'

module ReadFromSlave
  class Railtie < Rails::Railtie
    initializer 'read_from_slave.install_with_methods', :after=>"active_record.initialize_database" do |app|
      ReadFromSlave.install_with_methods!
    end
  end
end
