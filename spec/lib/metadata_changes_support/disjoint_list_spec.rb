# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MetadataChangesSupport::DisjointList do
  describe '#initialize' do
    it 'adds the elements of the list and caches info' do
      debugger
      list = MetadataChangesSupport::DisjointList.new([1, 2, 3])
      expect(list.to_a).to eq([1, 2, 3])
    end
  end

  describe '#sum_function_for' do
    let(:list) { MetadataChangesSupport::DisjointList.new([]) }
    it 'generates a sum function for the string provided' do
      expect(list.sum_function_for('123')).to eq(list.sum_function_for(123.to_s))
    end
    it 'always generates the same value for the same input' do
      expect(list.sum_function_for('abcdef')).to eq(list.sum_function_for('abcdef'))
    end
    it 'does not generate the same value for different inputs' do
      expect(list.sum_function_for('abcdef')).not_to eq(list.sum_function_for('ABCDEF'))
    end
  end

  describe '#unique_id_for_element' do
    let(:list) { MetadataChangesSupport::DisjointList.new([]) }
    it 'does not generate the same value for different inputs' do
      expect(list.unique_id_for_element('abcdef')).not_to eq(list.unique_id_for_element('ABCDEF'))
    end

    it 'always generates the same value for the same input' do
      expect(list.unique_id_for_element('abcdef')).to eq(list.unique_id_for_element('abcdef'))
    end
    it 'can generate an id for arrays' do
      expect(list.unique_id_for_element(%w[1 2 3])).to eq(list.unique_id_for_element([1, 2, 3]))
    end
    it 'can generate an id for hash' do
      expect(list.unique_id_for_element({ a: 1, b: 2, c: 3 })).to eq(list.unique_id_for_element({ a: '1', b: '2', c: '3' }))
    end
    it 'can generate an id for ActiveRecord' do
      fact1 = build(:fact, predicate: 'p', object: 'v')
      fact2 = build(:fact, predicate: 'p', object: 'v')
      expect(list.unique_id_for_element(fact1)).not_to eq(list.unique_id_for_element(fact2))
      expect(list.unique_id_for_element(fact1)).to eq(list.unique_id_for_element(fact1))
    end
    it 'can generate same id for different copies of the same ActiveRecord' do
      fact1 = build(:fact, predicate: 'p', object: 'v')
      f1 = Fact.where(predicate: 'p', object: 'v').first
      f2 = Fact.where(predicate: 'p').first
      expect(list.unique_id_for_element(f1)).to eq(list.unique_id_for_element(f2))
    end
    it 'can generate same id for different instances of the same model if they have the same uuid' do
      uuid = SecureRandom.uuid
      asset1 = build(:asset, uuid: uuid)
      asset2 = build(:asset, uuid: uuid)
      expect(list.unique_id_for_element(asset1)).to eq(list.unique_id_for_element(asset2))
    end
    it 'can generate an id for a relation' do
      fact1 = build(:fact, predicate: 'p', object: 'v')
      fact2 = build(:fact, predicate: 'r', object: 's')
      f1 = Fact.where(predicate: 'p', object: 'v')
      f2 = Fact.where(predicate: 'p')
      f3 = Fact.where(predicate: 'r')
      expect(list.unique_id_for_element(f1)).to eq(list.unique_id_for_element(f2))
      expect(list.unique_id_for_element(f1)).not_to eq(list.unique_id_for_element(f3))
    end
    it 'can generate ids for basic datatypes converting to string' do
      expect(list.unique_id_for_element(1)).to eq(list.unique_id_for_element('1'))
      expect(list.unique_id_for_element(true)).to eq(list.unique_id_for_element('true'))
      expect(list.unique_id_for_element(true)).not_to eq(list.unique_id_for_element(false))
    end
    it 'does not enter in infinite loop' do
      obj = { a: 1, b: { c: nil } }
      obj[:b][:c] = obj
      expect { list.unique_id_for_element(obj) }.not_to raise_error
    end
    it 'generates same id for facts when using id or object reference' do
      asset = build :asset
      asset2 = build :asset
      somepredicate = 'relation'
      ob1 = { asset: asset, predicate: somepredicate, object_asset: asset2 }
      ob2 = { id: 123, asset_id: asset.id, predicate: somepredicate, object_asset_id: asset2.id }
      expect(list.unique_id_for_element(ob1)).to eq(list.unique_id_for_element(ob2))
    end
    it 'generates different ids for facts using instances not in database' do
      asset = build :asset
      asset2 = build :asset
      asset3 = build :asset
      somepredicate = 'relation'

      ob1 = { asset: asset, predicate: somepredicate, object_asset: asset2 }
      ob2 = { asset: asset2, predicate: somepredicate, object_asset: asset }
      ob3 = { asset: asset, predicate: somepredicate, object_asset: asset3 }
      ob4 = { asset: asset, predicate: somepredicate, object_asset: asset }

      expect(list.unique_id_for_element(ob1)).not_to eq(list.unique_id_for_element(ob2))
      expect(list.unique_id_for_element(ob1)).not_to eq(list.unique_id_for_element(ob3))
      expect(list.unique_id_for_element(ob1)).not_to eq(list.unique_id_for_element(ob4))
    end
    it 'generates different ids for different instances' do
      asset = build :asset
      asset2 = build :asset
      expect(list.unique_id_for_element(asset)).not_to eq(list.unique_id_for_element(asset2))
    end
  end

  describe '#add' do
    let(:elem) { 'a value' }
    let(:raw_list) { [] }
    let(:raw_list2) { [] }
    let(:list) { MetadataChangesSupport::DisjointList.new(raw_list) }
    let(:list2) { MetadataChangesSupport::DisjointList.new(raw_list2) }

    before do
      list.add_disjoint_list(list2)
    end

    it 'returns the disjoint list' do
      expect(list.add(elem)).to eq(list)
    end
    it 'adds the element when is not present in any of the lists' do
      expect  do
        list.add(elem)
      end.to change { list.to_a.length }.by(1)
                                        .and change { list.length }.by(1)
      expect(list.to_a).to eq([elem])
    end
    it 'stores the position in the common hash' do
      expect  do
        list.add(elem)
      end.to change { list.store_for(elem) }.from(nil).to(list)
                                            .and change { list2.store_for(elem) }.from(nil).to(list)
    end
    it 'does not add the element again if it is already present' do
      list.add(elem)
      expect(list.to_a).to eq([elem])
      expect  do
        list.add(elem)
      end.to change { list.to_a.length }.by(0)
                                        .and change { list.length }.by(0)
      expect(list.to_a).to eq([elem])
    end
    it 'disables the element from the list if is added to another disjoint list' do
      list.add(elem)
      expect(list.to_a).to eq([elem])
      list2.add(elem)
      expect(list.to_a).to eq([])
      expect(list2.to_a).to eq([])
      expect(list.disabled?(elem)).to eq(true)
      expect(list.store_for(elem)).to eq(nil)
    end

    context 'with a group of disjoint lists' do
      let(:lists) do
        l = 5.times.map { MetadataChangesSupport::DisjointList.new([]) }
        l[0].add_disjoint_list(l[1])
        l[0].add_disjoint_list(l[2])
        l[0].add_disjoint_list(l[3])
        l[0].add_disjoint_list(l[4])
        l
      end
      it 'disables element if present in another list' do
        lists[0] << []
        lists[1] << [1]
        lists[2] << []
        lists[3] << []
        lists[4] << []

        lists[0] << [1]

        expect(lists[0].to_a).to eq([])
        expect(lists[1].to_a).to eq([])
      end

      it 'disables lists in another list' do
        lists[0] << [1, 2, 3, 4, 5]
        lists[1] << []
        lists[2] << []
        lists[3] << []
        lists[4] << [6, 7, 8, 9]

        lists[2] << [1, 2, 3, 4, 5, 6, 7, 8, 9]
        expect(lists[0].to_a).to eq([])
        expect(lists[1].to_a).to eq([])
        expect(lists[2].to_a).to eq([])
        expect(lists[3].to_a).to eq([])
        expect(lists[4].to_a).to eq([])
      end
    end
  end

  describe '#concat' do
    let(:disjoint1) { MetadataChangesSupport::DisjointList.new([]) }
    let(:disjoint2) { MetadataChangesSupport::DisjointList.new([]) }
    let(:disjoint3) { MetadataChangesSupport::DisjointList.new([]) }
    let(:disjoint4) { MetadataChangesSupport::DisjointList.new([]) }

    context 'when concatenating disjoint lists' do
      before do
        disjoint1.add_disjoint_list(disjoint2)
        disjoint3.add_disjoint_list(disjoint4)
      end
      it 'all disabled elements are rembered even in next actions after concat' do
        disjoint1 << []
        disjoint2 << []
        disjoint3 << ['rome']
        disjoint4 << %w[barcelona rome lisbon]
        # rome is disabled
        disjoint1.concat(disjoint3)
        disjoint1 << 'barcelona'
        disjoint1 << 'athens'
        disjoint1 << 'rome'
        expect(disjoint1.to_a).to eq(%w[barcelona athens])
      end
    end
  end

  describe '#remove' do
    let(:list) { MetadataChangesSupport::DisjointList.new([]) }
    let(:elem) { 'a value' }

    it 'removes the element with id from the list' do
      list.add(elem)
      expect(list.length).to eq(1)
      expect { list.remove(elem) }.to change { list.length }.by(-1)
                                                            .and change { list.store_for(elem) }.from(list).to(nil)
      expect(list.to_a).to eq([])
    end
  end
  describe '#add_disjoint_list' do
    let(:elem) { 'a value' }
    let(:elem2) { 'another value' }
    let(:list) { MetadataChangesSupport::DisjointList.new([]) }
    let(:list2) { MetadataChangesSupport::DisjointList.new([]) }
    let(:list3) { MetadataChangesSupport::DisjointList.new([]) }

    it 'adds the list to the disjoint lists' do
      expect { list.add_disjoint_list(list2) }.to change { list.disjoint_lists }.from([list]).to([list, list2])
                                                                                .and change { list2.disjoint_lists }.from([list2]).to([list, list2])
    end

    it 'sets up a shared list of disjoint lists for all added instances' do
      list.add_disjoint_list(list2)
      expect(list.disjoint_lists).to be(list2.disjoint_lists)

      list3 = MetadataChangesSupport::DisjointList.new([])
      expect { list3.add_disjoint_list(list2) }.to change { list.disjoint_lists }.from([list, list2]).to([list3, list, list2])
    end

    it 'sets up a common list of locations for all added instances' do
      list.add_disjoint_list(list2)
      list3.add_disjoint_list(list2)
      expect(list.location_for_unique_id).to be(list2.location_for_unique_id)
      expect(list3.location_for_unique_id).to be(list.location_for_unique_id)
      expect { list.add(elem) }.to change { list3.location_for_unique_id.keys.length }.by(1)
    end

    it 'disables all elements already disabled in the added list' do
      list2.add_disjoint_list(list3)
      list.add(elem)
      list2.add(elem)
      list3.add(elem)
      expect(list2.disabled?(elem)).to eq(true)
      expect(list.disabled?(elem)).to eq(false)
      expect { list.add_disjoint_list(list2) }.to change { list.disabled?(elem) }.from(false).to(true)
    end

    it 'removes the element if already present in my opposite list' do
      list.add_disjoint_list(list2)
      list << 'spiderman'
      list2 << 'superman'
      expect(list.to_a).to eq(['spiderman'])
      expect(list2.to_a).to eq(['superman'])
      list2 << 'spiderman'
      expect(list.to_a).to eq([])
      expect(list2.to_a).to eq(['superman'])
    end
  end

  describe '#include?' do
    let(:list) { MetadataChangesSupport::DisjointList.new([]) }
    let(:elem) { 'a value' }
    it 'returns true if the element was already added' do
      expect { list.add(elem) }.to change { list.include?(elem) }.from(false).to(true)
    end
    it 'returns false if the element is not on the list' do
      expect(list.include?(elem)).to eq(false)
      list.add(elem)
      expect { list.remove(elem) }.to change { list.include?(elem) }.from(true).to(false)
    end
  end

  describe '#merge' do
    let(:disjoint1) { MetadataChangesSupport::DisjointList.new([]) }
    let(:disjoint2) { MetadataChangesSupport::DisjointList.new([]) }
    let(:disjoint3) { MetadataChangesSupport::DisjointList.new([]) }
    let(:disjoint4) { MetadataChangesSupport::DisjointList.new([]) }

    let(:list2) { MetadataChangesSupport::DisjointList.new(facts_to_destroy) }

    context 'with mutual disjoint' do
      before do
        disjoint1.add_disjoint_list(disjoint2)
        disjoint3.add_disjoint_list(disjoint4)
      end

      it 'disables an element when adding it in my instance and removing it in the merged object' do
        disjoint1 << 'green'
        disjoint4 << 'green'

        expect { disjoint1.merge(disjoint3) }.to change { disjoint1.length }.by(-1)
      end

      it 'merges from different objects' do
        d1 = MetadataChangesSupport::DisjointList.new([1])
        d2 = MetadataChangesSupport::DisjointList.new([2])
        d3 = MetadataChangesSupport::DisjointList.new([3])

        d1.merge(d2).merge(d3)

        expect(d1.to_a).to eq([1, 2, 3])
      end

      it 'merges from different objects that have mutual disjoint' do
        d1 = MetadataChangesSupport::DisjointList.new([1])
        d2 = MetadataChangesSupport::DisjointList.new([2])
        d3 = MetadataChangesSupport::DisjointList.new([3])

        o1 = MetadataChangesSupport::DisjointList.new([4])
        o2 = MetadataChangesSupport::DisjointList.new([5])
        o3 = MetadataChangesSupport::DisjointList.new([6])

        d1.add_disjoint_list(o1)
        d2.add_disjoint_list(o2)
        d3.add_disjoint_list(o3)

        d1.merge(d2).merge(d3)

        expect(d1.to_a).to eq([1, 2, 3])
      end

      it 'can disable elements with every merge' do
        d1 = MetadataChangesSupport::DisjointList.new([1, 2, 3])
        d2 = MetadataChangesSupport::DisjointList.new([4])
        d3 = MetadataChangesSupport::DisjointList.new([5])

        o1 = MetadataChangesSupport::DisjointList.new([])
        o2 = MetadataChangesSupport::DisjointList.new([1, 2])
        o3 = MetadataChangesSupport::DisjointList.new([3])

        d1.add_disjoint_list(o1)
        d2.add_disjoint_list(o2)
        d3.add_disjoint_list(o3)

        d1.merge(d2).merge(d3)

        expect(d1.to_a).to eq([4, 5])
      end

      it 'does not re-enable elements after merge' do
        d1 = MetadataChangesSupport::DisjointList.new([1, 2, 3])
        d2 = MetadataChangesSupport::DisjointList.new([4])
        d3 = MetadataChangesSupport::DisjointList.new([1, 2])

        o1 = MetadataChangesSupport::DisjointList.new([])
        o2 = MetadataChangesSupport::DisjointList.new([1, 2])
        o3 = MetadataChangesSupport::DisjointList.new([3])

        d1.add_disjoint_list(o1)
        d2.add_disjoint_list(o2)
        d3.add_disjoint_list(o3)

        d1.merge(d2)
        expect(d1.to_a).to eq([3, 4])
        d1.merge(d3)
        expect(d1.to_a).to eq([4])
      end

      it 'merges the information removing values from the merged opposite disjoint list' do
        disjoint1 << %w[green yellow]
        disjoint2 << %w[white red]
        disjoint3 << %w[white blue]
        disjoint4 << %w[green black]

        disjoint1.merge(disjoint3)

        expect(disjoint1.to_a).to eq(%w[yellow blue])
      end

      context 'when merging a chain of objects' do
        let(:winners) { 6.times.map { MetadataChangesSupport::DisjointList.new([]) } }
        let(:losers) { 6.times.map { MetadataChangesSupport::DisjointList.new([]) } }
        let(:list) do
          winners.zip(losers).map do |l|
            l[0].add_disjoint_list(l[1])
            { winner: l[0], loser: l[1] }
          end
        end

        it 'keeps track of all restrictions until the final list' do
          list[0][:winner] << 'Manchester City'
          list[0][:loser] << 'Tottenham'
          list[1][:winner] << 'Liverpool'
          list[1][:loser] << 'Porto'
          list[2][:winner] << 'Ajax'
          list[2][:loser] << 'Tottenham'
          list[3][:winner] << 'Barcelona'
          list[3][:loser] << 'Liverpool'
          list[4][:winner] << 'Liverpool'
          list[4][:loser] << 'Barcelona'
          list[5][:winner] << 'Tottenham'
          list[5][:loser] << 'Ajax'

          winners = 6.times.map.each_with_object(MetadataChangesSupport::DisjointList.new([])) do |i, memo|
            memo.merge(list[i][:winner])
          end
          expect(winners.to_a.sort).to eq(['Manchester City'])
        end
      end
    end

    context 'when this object and the merged one have all an opposite disjoint' do
      before do
        disjoint1.add_disjoint_list(disjoint2)
        disjoint3.add_disjoint_list(disjoint4)
      end

      it 'adds all elements in both lists if no restrictions are found' do
        disjoint1 << 'green'
        disjoint3 << 'blue'
        expect { disjoint1.merge(disjoint3) }.to change { disjoint1.to_a }.from(['green']).to(%w[green blue])
      end

      it 'adds new elements keeping duplicates unique' do
        disjoint1 << %w[green red white]
        disjoint3 << %w[blue red white]
        expect { disjoint1.merge(disjoint3) }.to change {
                                                   disjoint1.to_a.sort
                                                 } .from(%w[green red white]).to(%w[blue green red white])
      end

      it 'merges the information of disjoint lists keeping duplicates unique' do
        disjoint1 << %w[green yellow]
        disjoint2 << %w[paris london rome]
        disjoint3 << %w[white green yellow]
        disjoint4 << %w[barcelona rome lisbon]

        disjoint1.merge(disjoint3)

        expect(disjoint1.to_a).to eq(%w[green yellow white])
        expect(disjoint2.to_a).to eq(%w[paris london])
      end

      it 'all restrictions are applied even in next actions after merging' do
        disjoint1 << []
        disjoint3 << []
        disjoint4 << %w[barcelona rome lisbon]
        disjoint1.merge(disjoint3)
        disjoint1 << 'barcelona'
        disjoint1 << 'athens'
        disjoint1 << 'rome'
        expect(disjoint1.to_a).to eq(['athens'])
      end
    end
  end
end
