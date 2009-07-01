# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{read_from_slave}
  s.version = "0.1.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Stephen Sykes"]
  s.date = %q{2009-07-01}
  s.description = %q{Read_from_slave for Rails enables database reads from a slave database, while writes continue to go to the master}
  s.email = %q{sdsykes@gmail.com}
  s.extra_rdoc_files = ["README", "README.textile"]
  s.files = ["Rakefile", "README", "README.textile", "VERSION.yml", "lib/read_from_slave.rb", "test/test.rb"]
  s.has_rdoc = true
  s.homepage = %q{http://github.com/sdsykes/read_from_slave}
  s.rdoc_options = ["--inline-source", "--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{Read_from_slave - Utilise your slave databases with rails}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
