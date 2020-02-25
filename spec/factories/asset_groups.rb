class AssetGroup < MockedModel
  attributes([:id, :uuid, :assets])
end

FactoryBot.define do
  sequence :asset_group_identifier do |n|
    n
  end

  factory :asset_group do
    id { generate :asset_group_identifier }
    uuid { SecureRandom.uuid }
    assets { [] }

  end
end
