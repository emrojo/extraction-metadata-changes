# frozen_string_literal: true

require 'spec_helper'
require 'extraction_token_util'
require 'json'

RSpec.describe MetadataChangesSupport::FactChanges do
  let(:uuid1) { SecureRandom.uuid }
  let(:uuid2) { SecureRandom.uuid }
  let(:asset_group1) { build :asset_group }
  let(:asset1) { build :asset }
  let(:asset2) { build :asset }
  let(:relation) { 'rel' }
  let(:property) { 'prop' }
  let(:value) { 'val' }
  let(:updates1) { MetadataChangesSupport::FactChanges.new }
  let(:updates2) { MetadataChangesSupport::FactChanges.new }
  let(:fact1) { build :fact, asset: asset1, predicate: property, object: value }
  let(:fact2) { build :fact, asset: asset1, predicate: relation, object_asset: asset2 }
  let(:json) { { "create_assets": ['?p', '?q'], "add_facts": [['?p', 'a', 'Plate']] }.to_json }

  describe '#new' do
    it 'parses a json and loads the config from it' do
      updates = MetadataChangesSupport::FactChanges.new(json)
      expect(updates.facts_to_add.length).to eq(1)
    end
  end

  describe '#parse_json' do
    let(:updates) { MetadataChangesSupport::FactChanges.new }
    it 'raises exception when the parsed object is not right' do
      expect do
        updates.parse_json('something went wrong!')
      end.to raise_error(StandardError)
    end
    it 'parses a json and loads the changes from it' do
      expect(updates.facts_to_add.length).to eq(0)
      updates.parse_json(json)
      expect(updates.facts_to_add.length).to eq(1)
    end
    it 'parses an empty json' do
      updates.parse_json('{}')
      expect(updates.facts_to_add.length).to eq(0)
    end
    it 'allows to add more changes after parsing' do
      updates.parse_json(json)
      expect(updates.facts_to_add.length).to eq(1)
      updates.add('?q', 'a', 'Tube')
      expect(updates.facts_to_add.length).to eq(2)
    end
    it 'does not destroy previously loaded changes' do
      updates.create_assets(['?q'])
      updates.add('?q', 'a', 'Tube')
      expect(updates.facts_to_add.length).to eq(1)
      updates.parse_json(json)
      expect(updates.facts_to_add.length).to eq(2)
    end

    context 'when loading different json' do
      let(:updates) { MetadataChangesSupport::FactChanges.new }
      it 'loads created assets' do
        uuid = SecureRandom.uuid
        json = { create_assets: [uuid] }.to_json
        expect(updates.parse_json(json)).to eq(true)
        expect(updates.assets_to_create.length).to eq(1)
      end
      it 'loads deleted assets' do
        uuid = build(:asset).uuid
        json = { delete_assets: [uuid] }.to_json
        expect(updates.parse_json(json)).to eq(true)
        expect(updates.assets_to_destroy.length).to eq(1)
      end
      it 'loads created groups' do
        uuid = build(:asset_group).uuid
        json = { create_asset_groups: [uuid] }.to_json
        expect(updates.parse_json(json)).to eq(true)
        expect(updates.asset_groups_to_create.length).to eq(1)
      end
      it 'loads deleted groups' do
        uuid = build(:asset_group).uuid
        json = { delete_asset_groups: [uuid] }.to_json
        expect(updates.parse_json(json)).to eq(true)
        expect(updates.asset_groups_to_destroy.length).to eq(1)
      end
      it 'loads added assets' do
        asset = build(:asset)
        group = build(:asset_group)
        json = { add_assets: [[group.uuid, [asset.uuid]]] }.to_json
        expect(updates.parse_json(json)).to eq(true)
        expect(updates.assets_to_add.length).to eq(1)
      end
      it 'loads removed assets' do
        asset = build(:asset)
        group = build(:asset_group)
        json = { remove_assets: [[group.uuid, [asset.uuid]]] }.to_json
        expect(updates.parse_json(json)).to eq(true)
        expect(updates.assets_to_remove.length).to eq(1)
      end
      it 'loads facts to add' do
        asset = build(:asset)
        json = { add_facts: [[asset.uuid, 'is', 'Cool']] }.to_json
        expect(updates.parse_json(json)).to eq(true)
        expect(updates.facts_to_add.length).to eq(1)
      end
      it 'loads removed facts' do
        asset = build(:asset)
        json = { remove_facts: [[asset.uuid, 'is', 'Cool']] }.to_json
        expect(updates.parse_json(json)).to eq(true)
        expect(updates.facts_to_destroy.length).to eq(1)
      end
    end
  end

  describe '#to_json' do
    let(:updates) { MetadataChangesSupport::FactChanges.new }
    it 'displays the contents of the object in json format' do
      updates.parse_json(json)
      expect(updates.to_json.is_a?(String)).to eq(true)
    end
  end

  describe '#to_h' do
    let(:updates) { MetadataChangesSupport::FactChanges.new }
    it 'generates a hash' do
      expect { updates.to_h }.not_to raise_error
    end
    it 'creates assets and adds them to the hash' do
      uuid = SecureRandom.uuid
      updates.create_assets([uuid])
      expect(updates.to_h).to include(create_assets: [uuid])
    end
    it 'adds deleted assets to the hash' do
      uuid = build(:asset).uuid
      updates.delete_assets([uuid])
      expect(updates.to_h).to include(delete_assets: [uuid])
    end
    it 'adds created groups to the hash' do
      uuid = SecureRandom.uuid
      updates.create_asset_groups([uuid])
      expect(updates.to_h).to include(create_asset_groups: [uuid])
    end
    it 'adds deleted groups to the hash' do
      uuid = build(:asset_group).uuid
      updates.delete_asset_groups([uuid])
      expect(updates.to_h).to include(delete_asset_groups: [uuid])
    end
    it 'adds added assets to the group in the hash' do
      asset = build(:asset)
      group = build(:asset_group)
      updates.add_assets([[group, [asset]]])
      expect(updates.to_h).to include(add_assets: [[group.uuid, [asset.uuid]]])
    end
    it 'adds removed assets from the group in the hash' do
      asset = build(:asset)
      group = build(:asset_group)
      updates.remove_assets([[group, [asset]]])
      expect(updates.to_h).to include(remove_assets: [[group.uuid, [asset.uuid]]])
    end
    it 'adds facts to the hash' do
      asset = build(:asset)
      updates.add(asset, 'is', 'Cool')
      expect(updates.to_h).to include(add_facts: [[asset.uuid, 'is', 'Cool']])
    end

    it 'adds removed facts into the hash' do
      asset = build(:asset)
      updates.remove_where(asset, 'is', 'Cool')
      expect(updates.to_h).to include(remove_facts: [[asset.uuid, 'is', 'Cool']])
    end
  end

  describe '#reset' do
    it 'resets the changes' do
      updates1.add(asset1, property, value)
      updates1.reset
      updates2.merge(updates1)
      expect(updates1.facts_to_add.length).to eq(0)
      expect(updates2.facts_to_add.length).to eq(0)
    end
  end
  describe '#add' do
    it 'raises error if we use a wildcard not created before' do
      expect { updates1.add('?p', property, value) }.to raise_error(StandardError)
    end
    it 'adds a new property' do
      expect(updates1.facts_to_add.length).to eq(0)
      updates1.add(asset1, property, value)
      expect(updates1.facts_to_add.length).to eq(1)
    end
    it 'adds a new relation' do
      expect(updates1.facts_to_add.length).to eq(0)
      updates1.add(asset1, relation, asset2)
      expect(updates1.facts_to_add.length).to eq(1)
    end
    context 'when the value is an uuid' do
      context 'when it represents a local asset' do
        let(:uuid) { build(:asset).uuid }
        it 'adds the relation' do
          expect(updates1.facts_to_add.length).to eq(0)
          updates1.add(asset1, relation, uuid)
          expect(updates1.facts_to_add.length).to eq(1)
        end
      end
      context 'when it does not represent a local asset' do
        let(:uuid) { SecureRandom.uuid }
        it 'does not add the property if the uuid is not quoted because it tries to find it in local' do
          expect(updates1.facts_to_add.length).to eq(0)
          expect { updates1.add(asset1, property, uuid) }.to raise_error(StandardError)
        end
        it 'adds the property when quoted' do
          expect(updates1.facts_to_add.length).to eq(0)
          updates1.add(asset1, property, ExtractionTokenUtil.quote(uuid))
          expect(updates1.facts_to_add.length).to eq(1)
        end
      end
    end
  end
  describe '#add_remote' do
    it 'adds a new fact in the facts to add list' do
      expect(updates1.facts_to_add.length).to eq(0)
      updates1.add_remote(asset1, relation, asset2)
      expect(updates1.facts_to_add.length).to eq(1)
    end
  end
  describe '#replace_remote' do
    it 'adds a new remote fact if it does not exist' do
      expect(updates1.facts_to_add.length).to eq(0)
      updates1.replace_remote(asset1, relation, asset2)
      expect(updates1.facts_to_add.length).to eq(1)
    end
    it 'replaces the local fact if a fact with the same predicate already exists' do
      asset3 = build(:asset)
      asset1.facts << build(:fact, predicate: relation, object_asset: asset3)
      asset1.save
      updates1.replace_remote(asset1, relation, asset2)
      expect(updates1.facts_to_add.length).to eq(1)
      expect(updates1.facts_to_destroy.length).to eq(1)
    end
  end
  describe '#remove' do
    it 'adds a fact to remove' do
      expect(updates1.facts_to_destroy.length).to eq(0)
      updates1.remove(fact1)
      expect(updates1.facts_to_destroy.length).to eq(1)
    end
  end

  describe '#remove_where' do
    it 'adds a property to remove' do
      expect(updates1.facts_to_destroy.length).to eq(0)
      updates1.remove_where(fact1.asset, fact1.predicate, fact1.object)
      expect(updates1.facts_to_destroy.length).to eq(1)
    end
    it 'adds a relation to remove' do
      expect(updates1.facts_to_destroy.length).to eq(0)
      updates1.remove_where(fact2.asset, fact2.predicate, fact2.object_asset)
      expect(updates1.facts_to_destroy.length).to eq(1)
    end
    it 'is able to work with uuids' do
      expect(updates1.facts_to_destroy.length).to eq(0)
      updates1.remove_where(fact2.asset.uuid, fact2.predicate, fact2.object_asset.uuid)
      expect(updates1.facts_to_destroy.length).to eq(1)
    end
    it 'does not add the same removal twice' do
      expect(updates1.facts_to_destroy.length).to eq(0)
      updates1.remove_where(fact1.asset, fact1.predicate, fact1.object)
      updates1.remove_where(fact1.asset, fact1.predicate, fact1.object)
      expect(updates1.facts_to_destroy.length).to eq(1)
    end
    context 'when the value object is an uuid' do
      context 'when it represents a local asset' do
        let(:uuid) { build(:asset).uuid }
        it 'adds the relation to remove' do
          expect(updates1.facts_to_destroy.length).to eq(0)
          updates1.remove_where(fact1.asset, fact1.predicate, uuid)
          expect(updates1.facts_to_destroy.length).to eq(1)
        end
      end
      context 'when it does not represent a local asset' do
        let(:uuid) { SecureRandom.uuid }
        it 'adds the property to remove if the uuid is quoted' do
          expect(updates1.facts_to_destroy.length).to eq(0)
          updates1.remove_where(fact1.asset, fact1.predicate, ExtractionTokenUtil.quote(uuid))
          expect(updates1.facts_to_destroy.length).to eq(1)
        end
        it 'does not add the property to remove if the uuid is not quoted because it tries to find it' do
          expect(updates1.facts_to_destroy.length).to eq(0)
          expect { updates1.remove_where(fact1.asset, fact1.predicate, uuid) }.to raise_error(StandardError)
        end
      end
    end
  end

  describe '#values_for_predicate' do
    it 'returns all the current values in the database' do
      asset = build(:asset)
      asset.facts << build(:fact, predicate: 'description', object: 'green')
      asset.facts << build(:fact, predicate: 'description', object: 'big')
      expect(updates1.values_for_predicate(asset, 'description')).to eq(%w[green big])
    end
    it 'returns all the values that will be added' do
      asset = build(:asset)
      updates1.add(asset, 'description', 'tall')
      updates1.add(asset, 'description', 'slim')
      expect(updates1.values_for_predicate(asset, 'description')).to eq(%w[tall slim])
    end
    it 'returns all the values both from the database and to add' do
      asset = build(:asset)
      asset.facts << build(:fact, predicate: 'description', object: 'green')
      asset.facts << build(:fact, predicate: 'description', object: 'big')
      updates1.add(asset, 'description', 'tall')
      updates1.add(asset, 'description', 'slim')
      expect(updates1.values_for_predicate(asset, 'description')).to eq(%w[green big tall slim])
    end

    it 'return the values at the database and to add without the values that will be removed' do
      asset = build(:asset)
      asset.facts << build(:fact, predicate: 'description', object: 'green')
      asset.facts << build(:fact, predicate: 'description', object: 'big')

      # These values are not in the database yet, so they won't be removed
      updates1.add(asset, 'description', 'tall')
      updates1.add(asset, 'description', 'slim')

      # This won't remove anything, as the value is not in database
      updates1.remove_where(asset, 'description', 'slim')
      updates1.remove_where(asset, 'description', 'green')

      expect(updates1.values_for_predicate(asset, 'description')).to eq(%w[big tall])
    end

    it 'does not return values from other instances' do
      asset = build(:asset)
      asset.facts << build(:fact, predicate: 'description', object: 'green')

      asset2 = build(:asset)
      asset2.facts << build(:fact, predicate: 'description', object: 'blue')

      updates1.add(asset, 'description', 'tall')
      updates1.add(asset2, 'description', 'small')

      expect(updates1.values_for_predicate(asset, 'description')).to eq(%w[green tall])
    end
  end

  describe '#create_assets' do
    it 'adds the list to the assets to create' do
      updates1.create_assets(['?p', '?q', '?r'])
      expect(updates1.assets_to_create.length).to eq(3)
    end
    it 'does not add twice the same asset' do
      updates1.create_assets(['?p', '?q', '?p'])
      expect(updates1.assets_to_create.length).to eq(2)
    end
    it 'does not raise error when referring to an asset not referred before' do
      expect { updates1.create_assets([SecureRandom.uuid]) }.not_to raise_error
    end
  end

  describe '#create_asset_groups' do
    it 'adds the list to the asset groups to create' do
      updates1.create_asset_groups(['?p', '?q', '?r'])
      expect(updates1.asset_groups_to_create.length).to eq(3)
    end
    it 'does not add twice the same asset' do
      updates1.create_asset_groups(['?p', '?q', '?p'])
      expect(updates1.asset_groups_to_create.length).to eq(2)
    end
    it 'does not raise error when referring to an asset not referred before' do
      expect { updates1.create_asset_groups([SecureRandom.uuid]) }.not_to raise_error
    end
  end

  describe '#delete_assets' do
    let(:asset1) { build(:asset, uuid: SecureRandom.uuid) }
    let(:asset2) { build(:asset, uuid: SecureRandom.uuid) }
    let(:asset3) { build(:asset, uuid: SecureRandom.uuid) }
    it 'adds the list to the assets to destroy' do
      updates1.delete_assets([asset1.uuid, asset2.uuid, asset3.uuid])
      expect(updates1.assets_to_destroy.length).to eq(3)
    end
    it 'does not add twice the same asset' do
      updates1.delete_assets([asset1.uuid, asset2.uuid, asset1.uuid])
      expect(updates1.assets_to_destroy.length).to eq(2)
    end
    it 'raises error when referring to an asset not referred before ' do
      expect { updates1.delete_assets([SecureRandom.uuid]) }.to raise_error(StandardError)
    end
  end

  describe '#delete_asset_groups' do
    let(:asset_group1) { build(:asset_group, uuid: SecureRandom.uuid) }
    let(:asset_group2) { build(:asset_group, uuid: SecureRandom.uuid) }
    let(:asset_group3) { build(:asset_group, uuid: SecureRandom.uuid) }
    it 'adds the list to the asset groups to destroy' do
      updates1.delete_asset_groups([asset_group1.uuid, asset_group2.uuid, asset_group3.uuid])
      expect(updates1.asset_groups_to_destroy.length).to eq(3)
    end
    it 'does not add twice the same asset' do
      updates1.delete_asset_groups([asset_group1.uuid, asset_group2.uuid, asset_group1.uuid])
      expect(updates1.asset_groups_to_destroy.length).to eq(2)
    end
    it 'raises error when referring to an asset not referred before ' do
      expect { updates1.delete_asset_groups([SecureRandom.uuid]) }.to raise_error(StandardError)
    end
  end

  describe '#add_assets' do
    let(:asset1) { build(:asset, uuid: SecureRandom.uuid) }
    let(:asset2) { build(:asset, uuid: SecureRandom.uuid) }
    let(:asset_group) { build(:asset_group, uuid: SecureRandom.uuid) }
    it 'adds the changes to the list of assets to add one for each asset' do
      updates1.add_assets([[asset_group, [asset1.uuid, asset2.uuid]]])
      expect(updates1.assets_to_add.length).to eq(2)
    end
    it 'does not add twice the same asset' do
      updates1.add_assets([[asset_group, [asset1.uuid, asset1.uuid]]])
      expect(updates1.assets_to_add.length).to eq(1)
    end
    it 'raises error when referring to an asset group not referred before ' do
      expect { updates1.add_assets([[SecureRandom.uuid, [asset1.uuid, asset2.uuid]]]) }.to raise_error(StandardError)
    end
  end

  describe '#remove_assets' do
    let(:asset1) { build(:asset, uuid: SecureRandom.uuid) }
    let(:asset2) { build(:asset, uuid: SecureRandom.uuid) }
    let(:asset_group) { build(:asset_group, uuid: SecureRandom.uuid) }
    it 'adds the changes to the list of assets to add one for each asset' do
      updates1.remove_assets([[asset_group, [asset1.uuid, asset2.uuid]]])
      expect(updates1.assets_to_remove.length).to eq(2)
    end
    it 'does not add twice the same asset' do
      updates1.remove_assets([[asset_group, [asset1.uuid, asset1.uuid]]])
      expect(updates1.assets_to_remove.length).to eq(1)
    end
    it 'raises error when referring to an asset group not referred before ' do
      expect { updates1.remove_assets([[SecureRandom.uuid, [asset1.uuid, asset2.uuid]]]) }.to raise_error(StandardError)
    end
  end

  describe '#add_assets_to_group' do
    let(:asset1) { build(:asset) }
    let(:asset2) { build(:asset) }
    let(:asset_group) { build :asset_group }
    let(:updates) { MetadataChangesSupport::FactChanges.new }
    let(:expectancy) do
      [{ asset_group: asset_group, asset: asset1 },
       { asset_group: asset_group, asset: asset2 }]
    end

    it 'add assets to a group' do
      expect do
        updates.add_assets_to_group(asset_group, [asset1, asset2])
      end.to change { updates.assets_to_add.to_a }.from([]).to(expectancy)
    end

    context 'when receiving an empty list' do
      it 'does nothing' do
        expect do
          updates.add_assets_to_group(asset_group, [])
        end.not_to change { updates.assets_to_add.to_a }
      end
    end
  end

  describe '#remove_assets_from_group' do
    let(:list) { 4.times.map { build(:asset, :with_barcode) } }
    let(:asset_group) { build(:asset_group, assets: list) }
    let(:updates) { MetadataChangesSupport::FactChanges.new }
    let(:expectancy) do
      [{ asset_group: asset_group, asset: asset1 },
       { asset_group: asset_group, asset: asset2 }]
    end

    it 'remove assets from a group' do
      expect do
        updates.remove_assets_from_group(asset_group, [asset1, asset2])
      end.to change { updates.assets_to_remove.to_a }.from([]).to(expectancy)
    end

    context 'when receiving an empty list' do
      it 'does nothing' do
        expect do
          updates.remove_assets_from_group(asset_group, [])
        end.not_to change { updates.assets_to_remove.to_a }
      end
    end
  end

  describe '#merge' do
    it 'returns another MetadataChangesSupport::FactChanges object' do
      expect(updates1.merge(updates2).is_a?(MetadataChangesSupport::FactChanges)).to eq(true)
    end
    it 'keeps track of elements already added/removed in previous object' do
      asset = build :asset
      fact = build(:fact, predicate: 'p', object: 'v')
      fact2 = build(:fact, predicate: 'p2', object: 'v2')
      asset.facts << fact
      asset.facts << fact2

      updates1.add(asset, fact.predicate, fact.object)
      updates1.add(asset, fact2.predicate, fact2.object)

      expect(updates1.facts_to_add.count).to eq(2)
      updates2.remove_where(asset, fact.predicate, fact.object)
      updates1.merge(updates2)
      expect(updates1.facts_to_add.count).to eq(1)
      expect(updates2.facts_to_destroy.count).to eq(1)
    end
    it 'keeps track of same fact added in one object and removed in another' do
      p = build :asset
      q = build :asset

      updates1.add(p, 'relates', q)
      updates2.remove_where(p, 'relates', q)

      updates1.merge(updates2)

      expect(updates1.to_h).to eq({})
    end
    it 'keeps track of disabled changes when merging an object' do
      p = build :asset
      q = build :asset

      updates2.add(p, 'relates', q)
      updates2.remove_where(p, 'relates', q)
      updates2.add(p, 'anotherRel', q)

      updates1.add(p, 'relates', q)

      updates1.merge(updates2)

      expect(updates1.to_h).to eq({ add_facts: [[p.uuid, 'anotherRel', q.uuid]] })
    end
    it 'keeps track of disabled changes after merging an object' do
      p = build :asset
      q = build :asset

      updates2.add(p, 'relates', q)
      updates2.remove_where(p, 'relates', q)
      updates2.add(p, 'anotherRel', q)

      updates1.merge(updates2)

      # This one is disabled in updates2
      updates1.add(p, 'relates', q)

      updates1.add(q, 'anotherRel', p)

      expect(updates1.to_h).to eq({ add_facts: [
                                    [p.uuid, 'anotherRel', q.uuid],
                                    [q.uuid, 'anotherRel', p.uuid]
                                  ] })
    end
    it 'disables an element because of changes merged' do
      p = build :asset
      q = build :asset

      updates2.add(p, 'relates', q)

      updates1.merge(updates2)

      expect(updates1.to_h).to eq({
                                    add_facts: [
                                      [p.uuid, 'relates', q.uuid]
                                    ]
                                  })

      updates1.remove_where(p, 'relates', q)

      expect(updates1.to_h).to eq({})
    end
    it 'merges changes and recalculates inconsistencies' do
      asset = build :asset
      asset2 = build :asset

      p = build :asset
      q = build :asset
      z = build :asset
      y = build :asset

      # 1 - will be removed by 4
      updates1.add(p, 'relates', q)
      # 2 - will be removed by 9
      updates1.add(asset, 'relates', asset2)
      # 3 - will be added by 6, so ignored
      updates1.remove_where(q, 'relates', asset)
      # 4 - OK
      updates1.add(p, 'relates', q)
      # 5 - OK
      updates2.add(q, 'relates', z)
      # 6 - invalidated by 3
      updates2.add(q, 'relates', asset)
      # 7 - OK
      updates2.remove_where(q, 'notRelates', z)
      # 8 - OK
      updates2.remove_where(q, 'relates', y)
      # 9 - Invalidated by 2
      updates2.remove_where(asset, 'relates', asset2)

      updates1.merge(updates2)

      expect(updates1.to_h).to include({
                                         add_facts: [
                                           [p.uuid, 'relates', q.uuid],
                                           [q.uuid, 'relates', z.uuid]
                                         ],
                                         remove_facts: [
                                           [q.uuid, 'notRelates', z.uuid],
                                           [q.uuid, 'relates', y.uuid]
                                         ]
                                       })
    end
    context 'when using wildcards' do
      let(:obj) { MetadataChangesSupport::FactChanges.new }
      let(:obj2) { MetadataChangesSupport::FactChanges.new }
      before do
        obj.create_assets(['?p'])
        obj2.merge(obj)
      end
      it 'merges wildcards used in other objects' do
        expect  do
          obj2.add('?p', 'a', 'Tube')
        end.not_to raise_error
      end
      it 'merges mapping between wildcards and uuids from other objects' do
        obj2.add('?p', 'a', 'Tube')
        expect(obj.wildcards['?p']).to eq(obj2.wildcards['?p'])
      end
      it 'merges instances generated from other objects' do
        obj2.add('?p', 'a', 'Tube')
        expect(obj.instances_from_uuid[obj.wildcards['?p']]).to eq(obj2.instances_from_uuid[obj2.wildcards['?p']])
      end
    end
    it 'merges changes from other objects' do
      expect(updates1.facts_to_add.length).to eq(0)
      expect(updates2.facts_to_add.length).to eq(0)
      updates1.add(asset1, relation, asset2)
      updates2.add(asset2, relation, asset1)
      expect(updates1.facts_to_add.length).to eq(1)
      expect(updates2.facts_to_add.length).to eq(1)
      updates2.merge(updates1)
      expect(updates1.facts_to_add.length).to eq(1)
      expect(updates2.facts_to_add.length).to eq(2)
    end
    it 'does not merge changes more than once' do
      expect(updates1.facts_to_add.length).to eq(0)
      expect(updates2.facts_to_add.length).to eq(0)
      updates1.add(asset1, relation, asset2)
      expect(updates1.facts_to_add.length).to eq(1)
      expect(updates2.facts_to_add.length).to eq(0)
      updates2.merge(updates1)
      updates2.merge(updates1)
      updates2.merge(updates1)
      expect(updates1.facts_to_add.length).to eq(1)
      expect(updates2.facts_to_add.length).to eq(1)
    end
    it 'does not merge duplicates' do
      expect(updates1.facts_to_add.length).to eq(0)
      expect(updates2.facts_to_add.length).to eq(0)
      updates1.add(asset1, relation, asset2)
      updates2.add(asset1, relation, asset2)
      expect(updates1.facts_to_add.length).to eq(1)
      expect(updates2.facts_to_add.length).to eq(1)
      updates2.merge(updates1)
      expect(updates1.facts_to_add.length).to eq(1)
      expect(updates2.facts_to_add.length).to eq(1)
    end
  end

  describe '#build_asset_groups' do
    it 'creates a new asset group' do
      expect(MetadataChangesSupport::FactChanges.new.build_asset_groups(['?p']).first.is_a?(AssetGroup)).to eq(true)
    end
  end
end
