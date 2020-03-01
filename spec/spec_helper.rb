# frozen_string_literal: true

require 'bundler/setup'
Bundler.setup

require 'byebug'

require 'support/mocked_model'
require 'support/mocked_relation'

require 'extraction_metadata_changes'
require 'extraction_metadata_changes/disjoint_list'
require 'extraction_metadata_changes/fact_changes'

require 'factory_bot'

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  config.before(:suite) do
    FactoryBot.find_definitions
  end
end
