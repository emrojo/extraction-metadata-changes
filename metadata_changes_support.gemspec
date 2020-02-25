Gem::Specification.new do |s|
  s.name = %q{metadata_changes_support}
  s.version = "0.0.1"
  s.version = "#{s.version}-alpha-#{ENV['TRAVIS_BUILD_NUMBER']}" if ENV['TRAVIS']
  s.date = %q{2020-02-22}
  s.summary = %q{Set of tools to provide transactions and tracking of changes for metadata updates}
  s.files = Dir["{lib}/**/*.rb", "bin/*", "LICENSE", "*.md"]
  s.require_paths = ["lib"]
  s.authors = ["Eduardo Martin Rojo"]
  s.license = "MIT"
  s.homepage = "https://rubygems.org/gems/metadata_changes_support"

  s.add_dependency "google_hash", '~> 0.9'
  s.add_dependency "extraction_token_util", '~> 0.0.2'
  s.add_development_dependency "rspec", '~> 3'
  s.add_development_dependency "factory_bot", '~> 5'
  s.add_development_dependency "pry"
end
