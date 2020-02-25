FactoryBot.define do
  sequence :barcode do |n|
    "FF#{n}"
  end
end
