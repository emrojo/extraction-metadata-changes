# frozen_string_literal: true

FactoryBot.define do
  sequence :barcode do |n|
    "FF#{n}"
  end
end
