# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name = 'extraction_metadata_changes'
  version = '0.0.1a'
  version += (ENV['TRAVIS_BUILD_NUMBER']).to_s if version.end_with?('a')
  s.version = version
  s.date = '2020-02-22'
  s.summary = %(Client interface tool that talks with the metadata service to store and apply all
metadata modifications in a single transaction)
  s.files = Dir['{lib}/**/*.rb', 'bin/*', 'LICENSE', '*.md']
  s.require_paths = ['lib']
  s.authors = ['Eduardo Martin Rojo']
  s.license = 'MIT'
  s.homepage = 'https://rubygems.org/gems/extraction_metadata_changes'

  s.add_dependency 'extraction_token_util', '~> 0.0.3a11'
  s.add_dependency 'google_hash', '~> 0.9'
  s.add_development_dependency 'byebug'
  s.add_development_dependency 'factory_bot', '~> 5'
  s.add_development_dependency 'pry'
  s.add_development_dependency 'rspec', '~> 3'
  s.add_development_dependency 'rubocop', '~> 0.80'
  s.add_development_dependency 'rubocop-rspec'
end
