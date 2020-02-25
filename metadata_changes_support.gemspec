# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name = 'metadata_changes_support'
  version = '0.0.1a'
  version += (ENV['TRAVIS_BUILD_NUMBER']).to_s if version.end_with?('a')
  s.version = version
  s.date = '2020-02-22'
  s.summary = 'Set of tools to provide transactions and tracking of changes for metadata updates'
  s.files = Dir['{lib}/**/*.rb', 'bin/*', 'LICENSE', '*.md']
  s.require_paths = ['lib']
  s.authors = ['Eduardo Martin Rojo']
  s.license = 'MIT'
  s.homepage = 'https://rubygems.org/gems/metadata_changes_support'

  s.add_dependency 'extraction_token_util', '~> 0.0.3a11'
  s.add_dependency 'google_hash', '~> 0.9'
  s.add_development_dependency 'byebug'
  s.add_development_dependency 'factory_bot', '~> 5'
  s.add_development_dependency 'pry'
  s.add_development_dependency 'rspec', '~> 3'
  s.add_development_dependency 'rubocop', '~> 0.80'
  s.add_development_dependency 'rubocop-rspec'
end
