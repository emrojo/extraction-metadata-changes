require 'spec_helper'

RSpec.describe MetadataChangesSupport::TransactionScope do
  let(:updates) { MetadataChangesSupport::FactChanges.new }
  context '#transaction_scope' do
    it 'returns a ModelAccessor object' do
      expect(updates.transaction_scope(Asset).kind_of?(MetadataChangesSupport::TransactionScope::ModelAccessor)).to eq(true)
    end
    it 'returns the same object when calling it several times' do
      expect(updates.transaction_scope(Asset)).to be(updates.transaction_scope(Asset))
    end
  end

  describe 'TransactionScope::ModelAccessor' do
    let(:accessor) { updates.transaction_scope(Asset)}
    context '#where' do
      it 'returns data from the database' do
        asset = create :asset
        expect(accessor.where(id: asset.id).first).to eq(asset)
      end
      it 'returns non-existing elements created during transaction' do
        uuid = SecureRandom.uuid
        updates.create_assets([uuid])
        updates.add(uuid, 'a', 'Plate')
        expect(accessor.where(uuid: uuid).first.kind_of?(Asset)).to eq(true)
      end
      it 'does not return deleted elements during transaction' do
        asset = create :asset
        updates.delete_assets([asset.uuid])

        expect(accessor.where(id: asset.id).first).to eq(nil)
      end
      it 'can concat several conditions' do
        uuid = SecureRandom.uuid
        uuid2 = SecureRandom.uuid
        create(:asset, uuid: uuid, barcode: '1')
        asset2 = create(:asset, uuid: uuid2, barcode: '1')
        expect(accessor.where(barcode: '1').where(uuid: uuid2).first).to eq(asset2)
      end
      context 'when the condition is met in the Changes object' do
        it 'can join with different models' do
          uuid = SecureRandom.uuid
          uuid2 = "2f94cc54-bb96-46a7-b977-9ee0fb7f7dfd"
          uuid3 = SecureRandom.uuid
          updates.create_assets([uuid, uuid2, uuid3])
          updates.add(uuid, 'a', 'Tube')
          updates.add(uuid, 'is', 'Full')
          updates.add(uuid2, 'is', 'Empty')
          updates.add(uuid3, 'a', 'Tube')
          expect(accessor.joins(:facts).where(facts: {predicate: 'a', object: 'Tube'}).map(&:uuid)).to eq([uuid, uuid3])
        end
      end
      context 'when the condition is met in the database' do
        it 'can join with different models' do
          asset1 = create :asset
          asset2 = create :asset
          asset3 = create :asset
          asset1.facts << create(:fact, predicate: 'a', object: 'Tube')
          asset2.facts << create(:fact, predicate: 'is', object: 'Full')
          asset3.facts << create(:fact, predicate: 'is', object: 'Empty')
          asset3.facts << create(:fact, predicate: 'a', object: 'Tube')
          expect(accessor.joins(:facts).where(facts: {predicate: 'a', object: 'Tube'}).map(&:uuid)).to eq([
            asset1.uuid, asset3.uuid
            ])
        end
      end
      context 'when the condition are met both in the Changes and in the database' do
        it 'can join with different models with added data' do
          uuid = SecureRandom.uuid
          uuid2 = "2f94cc54-bb96-46a7-b977-9ee0fb7f7dfd"
          asset3 = create :asset
          updates.create_assets([uuid, uuid2])
          updates.add(uuid, 'a', 'Tube')
          updates.add(uuid, 'is', 'Full')
          updates.add(uuid2, 'is', 'Empty')
          asset3.facts << create(:fact, predicate: 'is', object: 'Empty')
          asset3.facts << create(:fact, predicate: 'a', object: 'Tube')
          expect(accessor.joins(:facts).where(facts: {predicate: 'a', object: 'Tube'}).map(&:uuid).sort).to eq([uuid, asset3.uuid].sort)
        end
        it 'can join with different models with removed data' do
          uuid = "fdd84c08-2aa3-4e3f-a39c-06ad35228d00"
          uuid2 = "2f94cc54-bb96-46a7-b977-9ee0fb7f7dfd"
          asset3 = create :asset, uuid: "5e142000-a574-4554-b0a3-8babe228addd"
          updates.create_assets([uuid, uuid2])
          updates.add(uuid, 'a', 'Tube')
          updates.add(uuid, 'is', 'Full')
          updates.add(uuid2, 'is', 'Empty')
          asset3.facts << create(:fact, predicate: 'is', object: 'Empty')
          asset3.facts << create(:fact, predicate: 'a', object: 'Tube')
          updates.remove_where(asset3.uuid, 'a', 'Tube')
          expect(accessor.joins(:facts).where(facts: {predicate: 'a', object: 'Tube'}).map(&:uuid)).to eq([uuid])
        end
      end
    end
    context '#find' do
      it 'returns data from the database' do
        asset = create :asset
        expect(accessor.find(asset.id)).to eq(asset)
      end
    end
  end
end
