class Asset < MockModel
  attributes([:id, :asset, :barcode, :uuid, :facts])
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
    facts { [] }

  end
end
