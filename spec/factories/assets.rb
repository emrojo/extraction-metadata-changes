# frozen_string_literal: true

class Asset < MockedModel
  attributes(%i[id asset barcode uuid facts])
end

FactoryBot.define do
  sequence :asset_identifier do |n|
    n
  end

  factory :asset do
    trait :with_barcode do
      barcode { generate :barcode }
    end
    id { generate :asset_identifier }
    uuid { SecureRandom.uuid }
    barcode { nil }
    facts { MockedRelation.new([]) }

    after(:build) do |asset|
      asset.facts.set_parent(asset)
    end
  end
end
