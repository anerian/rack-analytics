# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{rack-analytics}
  s.version = "0.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Anerian LLC"]
  s.autorequire = %q{rack-analytics}
  s.date = %q{2009-04-22}
  s.description = %q{A gem that provides rack middlware to analyze Rails apps}
  s.email = %q{dev@anerian.com}
  s.extra_rdoc_files = ["README", "LICENSE", "TODO"]
  s.files = ["LICENSE", "README", "Rakefile", "TODO", "lib/rack-analytics.rb", "spec/rack-analytics_spec.rb", "spec/spec_helper.rb"]
  s.has_rdoc = true
  s.homepage = %q{http://anerian.com}
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.2}
  s.summary = %q{A gem that provides rack middlware to analyze Rails apps}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
