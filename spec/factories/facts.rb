# frozen_string_literal: true

class Fact < MockedModel
  attributes(%i[
               id asset asset_id predicate object
               object_asset object_asset_id literal
             ])

  def self.with_predicate(pred)
    where(predicate: pred)
  end
end

FactoryBot.define do
  sequence :fact_identifier do |n|
    n
  end

  factory :fact do
    id { generate :fact_identifier }
    asset { nil }
    predicate { nil }
    object { nil }
    object_asset { nil }
    asset_id { asset&.id }
    object_asset_id { object_asset&.id }
    literal { false }
  end
end
