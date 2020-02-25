require 'bundler/setup'
Bundler.setup

require 'byebug'

require 'support/mocked_model'
require 'support/mocked_relation'

require 'metadata_changes_support'
require 'metadata_changes_support/disjoint_list'
require 'metadata_changes_support/fact_changes'

require 'factory_bot'

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  config.before(:suite) do
    FactoryBot.find_definitions
  end
end
