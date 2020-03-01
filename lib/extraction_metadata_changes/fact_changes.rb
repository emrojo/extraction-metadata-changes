# frozen_string_literal: true

require 'securerandom'
require 'extraction_token_util'

module ExtractionMetadataChanges
  #
  # Any change of metadata is composed of small modifications related with each other
  # that can be applied in a transactional way so they can be cancelled, rolledback, etc.
  #
  # *About DisjointList*
  #
  # To be able to merge different configurations of changes, we need a way to keep track
  # on the properties and values that have been added and removed to keep the modifications
  # consistent, to avoid performing the operation twice, or in a wrong way.
  #
  # For instance, in these operations:
  #
  # > changes.add('?my_car', 'color', 'Red')
  # > changes.remove_where('?my_car', 'color', 'Red')
  #
  # This modifications have opposite meaning so they do not apply at all, but if we add this:
  #
  # > changes.add('?my_car', 'color', 'Bright')
  #
  # It can apply because it refers to a different value. All this logic about when a property
  # should not be part of the final transaction is performed using the DisjointList class,
  # by establishing a disjoint relations between opposite lists (added properties,
  # removed properties, etc...)
  #
  #
  class FactChanges
    attr_accessor :facts_to_destroy, :facts_to_add, :assets_to_create, :assets_to_destroy,
                  :assets_to_add, :assets_to_remove, :wildcards, :instances_from_uuid,
                  :asset_groups_to_create, :asset_groups_to_destroy, :errors_added,
                  :already_added_to_list, :instances_by_unique_id,
                  :facts_to_set_to_remote

    attr_accessor :operations

    def initialize(json = nil)
      @assets_updated = []
      reset
      parse_json(json) if json
    end

    def parsing_valid?
      @parsing_valid
    end

    def reset
      @parsing_valid = false
      @errors_added = []

      @facts_to_set_to_remote = []

      build_disjoint_lists(:facts_to_add, :facts_to_destroy)
      build_disjoint_lists(:assets_to_create, :assets_to_destroy)
      build_disjoint_lists(:asset_groups_to_create, :asset_groups_to_destroy)
      build_disjoint_lists(:assets_to_add, :assets_to_remove)

      @instances_from_uuid = GoogleHashDenseRubyToRuby.new
      @wildcards = GoogleHashDenseRubyToRuby.new
    end

    def build_disjoint_lists(list, opposite)
      list1 = ExtractionMetadataChanges::DisjointList.new([])
      list2 = ExtractionMetadataChanges::DisjointList.new([])

      list1.add_disjoint_list(list2)

      send("#{list}=", list1)
      send("#{opposite}=", list2)
    end

    def asset_group_asset_to_h(asset_group_asset_str)
      obj = asset_group_asset_str.each_with_object({}) do |o, memo|
        key = o[:asset_group]&.uuid || nil
        memo[key] = [] unless memo[key]
        memo[key].push(o[:asset].uuid)
      end
      obj.map do |k, v|
        [k, v]
      end
    end

    def to_h
      {
        'set_errors': @errors_added,
        'create_assets': @assets_to_create.map(&:uuid),
        'create_asset_groups': @asset_groups_to_create.map(&:uuid),
        'delete_asset_groups': @asset_groups_to_destroy.map(&:uuid),
        'delete_assets': @assets_to_destroy.map(&:uuid),
        'add_facts': @facts_to_add.map do |f|
          [
            f[:asset].nil? ? nil : f[:asset].uuid,
            f[:predicate],
            (f[:object] || f[:object_asset].uuid)
          ]
        end,
        'remove_facts': @facts_to_destroy.map do |f|
          if f[:id]
            fact = Fact.find(f[:id])
            [fact.asset.uuid, fact.predicate, fact.object_value_or_uuid]
          else
            [
              f[:asset].nil? ? nil : f[:asset].uuid,
              f[:predicate],
              (f[:object] || f[:object_asset].uuid)
            ]
          end
        end,
        'add_assets': asset_group_asset_to_h(@assets_to_add),
        'remove_assets': asset_group_asset_to_h(@assets_to_remove)
      }.reject { |_k, v| v.empty? }
    end

    def to_json(*_args)
      JSON.pretty_generate(to_h)
    end

    def parse_json(json)
      obj = JSON.parse(json)
      %w[set_errors create_assets create_asset_groups delete_asset_groups
         remove_facts add_facts delete_assets add_assets remove_assets].each do |action_type|
        send(action_type, obj[action_type]) if obj[action_type]
      end
      @parsing_valid = true
    end

    def values_for_predicate(asset, predicate)
      actual_values = asset.facts.with_predicate(predicate).map(&:object)
      values_to_add = facts_to_add.map do |f|
        f[:object] if (f[:asset] == asset) && (f[:predicate] == predicate)
      end.compact
      values_to_destroy = facts_to_destroy.map do |f|
        f[:object] if (f[:asset] == asset) && (f[:predicate] == predicate)
      end.compact
      (actual_values + values_to_add - values_to_destroy)
    end

    def _build_fact_attributes(asset, predicate, object, options = {})
      t = [asset, predicate, object, options]
      params = { asset: t[0], predicate: t[1], literal: !t[2].is_a?(Asset) }
      params[:literal] ? params[:object] = t[2] : params[:object_asset] = t[2]
      params = params.merge(t[3]) if t[3]
      params
    end

    def add(asset, predicate, object, options = {})
      asset = find_asset(asset)
      object = options[:literal] == true ? literal_token(object) : find_asset(object)

      fact = _build_fact_attributes(asset, predicate, object, options)

      facts_to_add << fact if fact
    end

    def literal_token(str)
      ExtractionTokenUtil.quote_if_uuid(str)
    end

    def add_facts(lists)
      lists.each { |list| add(list[0], list[1], list[2]) }
      self
    end

    def remove_facts(lists)
      lists.each { |list| remove_where(list[0], list[1], list[2]) }
      self
    end

    def add_remote(asset, predicate, object, options = {})
      return unless asset && predicate && object

      add(asset, predicate, object, options.merge({ is_remote?: true }))
    end

    def replace_remote_relation(asset, predicate, object_asset, options = {})
      replace_remote(asset, predicate, object_asset, options.merge({ literal: false }))
    end

    def replace_remote_property(asset, predicate, value, options = {})
      replace_remote(asset, predicate, value, options.merge({ literal: true }))
    end

    def replace_remote(asset, predicate, object, options = {})
      return unless asset && predicate && object

      asset.facts.with_predicate(predicate).each do |fact|
        # The value is updated from the remote instance so we remove the previous value
        remove(fact)
        # In any case they will be set as Remote, even if they are not removed in this update
        facts_to_set_to_remote << fact
      end
      add_remote(asset, predicate, object, options)
    end

    def remove(fact)
      return if fact.nil?

      if fact.is_a?(Enumerable)
        facts_to_destroy << fact.map { |o| o.attributes.symbolize_keys }
      elsif fact.is_a?(Fact)
        facts_to_destroy << fact.attributes.symbolize_keys if fact
      end
    end

    def remove_where(subject, predicate, object)
      subject = find_asset(subject)
      object = find_asset(object)

      fact = _build_fact_attributes(subject, predicate, object)

      facts_to_destroy << fact if fact
    end

    def errors?
      to_h.key?(:set_errors)
    end

    def merge_hash(hash1, hash2)
      hash2.keys.each do |k|
        hash1[k] = hash2[k]
      end
      hash1
    end

    def merge(fact_changes)
      if fact_changes
        # To keep track of already added object after merging with another fact changes object
        # _add_already_added_from_other_object(fact_changes)
        errors_added.concat(fact_changes.errors_added)
        asset_groups_to_create.concat(fact_changes.asset_groups_to_create)
        assets_to_create.concat(fact_changes.assets_to_create)
        facts_to_add.concat(fact_changes.facts_to_add)
        assets_to_add.concat(fact_changes.assets_to_add)
        assets_to_remove.concat(fact_changes.assets_to_remove)
        facts_to_destroy.concat(fact_changes.facts_to_destroy)
        assets_to_destroy.concat(fact_changes.assets_to_destroy)
        asset_groups_to_destroy.concat(fact_changes.asset_groups_to_destroy)
        merge_hash(instances_from_uuid, fact_changes.instances_from_uuid)
        merge_hash(wildcards, fact_changes.wildcards)
      end
      self
    end

    def apply(step, with_operations = true)
      _handle_errors(step) unless errors_added.empty?
      ActiveRecord::Base.transaction do |_t|
        # We need step to have an allocated id to be able to link it with the operations
        # so we have to create a new record if is not already stored
        step.save unless step.persisted?

        # Callbacks execution
        _on_apply(step) if respond_to?(:_on_apply)

        _set_remote_facts(facts_to_set_to_remote)

        # Creates the facts and generate from it the list of operations
        operations = [
          _create_asset_groups(step, asset_groups_to_create, with_operations),
          _create_assets(step, assets_to_create, with_operations),
          _add_assets(step, assets_to_add, with_operations),
          _remove_assets(step, assets_to_remove, with_operations),
          _remove_facts(step, facts_to_destroy, with_operations),
          _detach_assets(step, assets_to_destroy, with_operations),
          _detach_asset_groups(step, asset_groups_to_destroy, with_operations),
          _create_facts(step, facts_to_add, with_operations)
        ].flatten.compact

        # Writes all operations in a single call
        unless operations.empty?
          Operation.import(operations)
          @operations = operations
        end
        step.save if step.changed?
        _handle_errors(step) unless errors_added.empty?
        reset
      end
    end

    def assets_updated
      return [] unless @operations

      @assets_updated = Asset.where(id: @operations.pluck(:asset_id).uniq).distinct
    end

    def assets_for_printing
      return [] unless @operations

      asset_ids = @operations.select do |operation|
        (operation.action_type == 'createAssets')
      end.pluck(:object).uniq

      ready_for_print_ids = @operations.select do |operation|
        ((operation.action_type == 'addFacts') &&
        (operation.predicate == 'is') &&
        (operation.object == 'readyForPrint'))
      end.map(&:asset).compact.uniq.map(&:uuid)

      ids_for_print = asset_ids.concat(ready_for_print_ids).flatten.uniq
      @assets_for_printing = Asset.for_printing.where(uuid: ids_for_print)
    end

    def find_asset(asset_or_uuid)
      find_instance_of_class_by_uuid(Asset, asset_or_uuid)
    end

    def find_asset_group(asset_group_or_id)
      find_instance_of_class_by_uuid(AssetGroup, asset_group_or_id)
    end

    def find_assets(assets_or_uuids)
      assets_or_uuids.uniq.map do |asset_or_uuid|
        find_instance_of_class_by_uuid(Asset, asset_or_uuid)
      end
    end

    def build_assets(assets)
      assets.uniq.map do |asset_or_uuid|
        find_instance_of_class_by_uuid(Asset, asset_or_uuid, true)
      end
    end

    def find_asset_groups(asset_groups_or_uuids)
      asset_groups_or_uuids.uniq.map do |asset_group_or_uuid|
        find_instance_of_class_by_uuid(AssetGroup, asset_group_or_uuid)
      end
    end

    def build_asset_groups(asset_groups)
      asset_groups.uniq.map do |asset_group_or_uuid|
        find_instance_of_class_by_uuid(AssetGroup, asset_group_or_uuid, true)
      end
    end

    def new_record?(uuid)
      (instances_from_uuid[uuid] && instances_from_uuid[uuid].new_record?) == true
    end

    def find_instance_of_class_by_uuid(klass, instance_or_uuid_or_id, create = false)
      if ExtractionTokenUtil.wildcard?(instance_or_uuid_or_id)
        uuid = uuid_for_wildcard(instance_or_uuid_or_id)
        # Do not try to find it if it is a new wildcard created
        found = find_instance_from_uuid(klass, uuid) unless create
        found = ((instances_from_uuid[uuid] ||= klass.new(uuid: uuid))) if !found && create
      elsif ExtractionTokenUtil.uuid?(instance_or_uuid_or_id)
        found = find_instance_from_uuid(klass, instance_or_uuid_or_id)
        if !found && create
          found = ((instances_from_uuid[instance_or_uuid_or_id] ||= klass.new(
            uuid: instance_or_uuid_or_id
          )))
        end
      else
        found = instance_or_uuid_or_id
      end
      unless found
        _produce_error([%(
          Element identified by #{instance_or_uuid_or_id} should be declared before using it
        )])
      end
      found
    end

    def uuid_for_wildcard(wildcard)
      wildcards[wildcard] ||= SecureRandom.uuid
    end

    def wildcard_for_uuid(uuid)
      wildcards.keys.select { |key| wildcards[key] == uuid }.first
    end

    def find_instance_from_uuid(klass, uuid)
      found = klass.find_by(uuid: uuid) unless new_record?(uuid)
      return found if found

      instances_from_uuid[uuid]
    end

    def validate_instances(instances)
      if instances.is_a?(Array)
        instances.each { |a| raise StandardError, a if a.nil? }
      else
        raise StandardError, a if instances.nil?
      end
      instances
    end

    def set_errors(errors)
      errors_added.concat(errors)
      self
    end

    def create_assets(assets)
      assets_to_create << validate_instances(build_assets(assets))
      # assets_to_create.concat(validate_instances(build_assets(assets)))
      self
    end

    def create_asset_groups(asset_groups)
      asset_groups_to_create << validate_instances(build_asset_groups(asset_groups))
      self
    end

    def delete_asset_groups(asset_groups)
      asset_groups_to_destroy << validate_instances(find_asset_groups(asset_groups))
      self
    end

    def delete_assets(assets)
      assets_to_destroy << validate_instances(find_assets(assets))
      self
    end

    def add_assets_to_group(group, assets)
      add_assets([[group, assets]])
    end

    def remove_assets_from_group(group, assets)
      remove_assets([[group, assets]])
    end

    def add_assets(list)
      list.each do |elem|
        if !elem.empty? && elem[1].is_a?(Array)
          asset_group = elem[0].nil? ? nil : validate_instances(find_asset_group(elem[0]))
          asset_ids = elem[1]
        else
          asset_group = nil
          asset_ids = elem
        end
        assets = validate_instances(find_assets(asset_ids))
        assets_to_add << assets.map { |asset| { asset_group: asset_group, asset: asset } }
      end
      self
    end

    def remove_assets(list)
      list.each do |elem|
        if !elem.empty? && elem[1].is_a?(Array)
          asset_group = elem[0].nil? ? nil : validate_instances(find_asset_group(elem[0]))
          asset_ids = elem[1]
        else
          asset_group = nil
          asset_ids = elem
        end
        assets = validate_instances(find_assets(asset_ids))
        assets_to_remove << assets.map { |asset| { asset_group: asset_group, asset: asset } }
      end
      self
    end

    private

    def _handle_errors(step)
      step.set_errors(errors_added)
      _produce_error(errors_added) unless errors_added.empty?
    end

    def _produce_error(errors_added)
      raise StandardError.new(message: errors_added.join("\n"))
    end

    def _set_remote_facts(facts)
      Fact.where(id: facts.map(&:id).uniq.compact).update_all(is_remote?: true)
    end

    def _add_assets(step, asset_group_assets, with_operations = true)
      modified_list = asset_group_assets.map do |o|
        # If is nil, it will use the asset group from the step
        o[:asset_group] = o[:asset_group] || step.asset_group
        o
      end
      _instance_builder_for_import(AssetGroupsAsset, modified_list) do |instances|
        _asset_group_operations('addAssets', step, instances) if with_operations
      end
    end

    def _remove_assets(step, assets_to_remove, with_operations = true)
      modified_list = assets_to_remove.map do |obj|
        AssetGroupsAsset.where(
          asset_group: obj[:asset_group] || step.asset_group,
          asset: obj[:asset]
        )
      end
      _instances_deletion(AssetGroupsAsset, modified_list) do |asset_group_assets|
        _asset_group_operations('removeAssets', step, asset_group_assets) if with_operations
      end
    end

    def _create_assets(step, assets, with_operations = true)
      return unless assets

      _instance_builder_for_import(Asset, assets) do |_instances|
        _asset_operations('createAssets', step, assets) if with_operations
      end
    end

    def _detach_assets(step, assets, with_operations = true)
      operations = _asset_operations('deleteAssets', step, assets) if with_operations
      _instances_deletion(Fact, assets.map(&:facts).flatten.compact)
      _instances_deletion(AssetGroupsAsset, assets.map(&:asset_groups_assets).flatten.compact)
      operations
    end

    def _create_asset_groups(step, asset_groups, with_operations = true)
      return unless asset_groups

      asset_groups.each_with_index do |asset_group, _index|
        asset_group.update_attributes(
          name: ExtractionTokenUtil.to_asset_group_name(wildcard_for_uuid(asset_group.uuid)),
          activity_owner: step.activity
        )
        asset_group.save
      end
      _asset_group_building_operations('createAssetGroups', step, asset_groups) if with_operations
    end

    def _detach_asset_groups(step, asset_groups, with_operations = true)
      if with_operations
        operations = _asset_group_building_operations('deleteAssetGroups', step, asset_groups)
      end
      instances = asset_groups.flatten
      ids_to_remove = instances.map(&:id).compact.uniq

      if ids_to_remove && !ids_to_remove.empty?
        AssetGroup.where(id: ids_to_remove).update_all(activity_owner_id: nil)
      end
      operations
    end

    def _create_facts(step, params_for_facts, with_operations = true)
      _instance_builder_for_import(Fact, params_for_facts) do |facts|
        _fact_operations('addFacts', step, facts) if with_operations
      end
    end

    def _remove_facts(step, facts_to_remove, with_operations = true)
      ids = []
      modified_list = facts_to_remove.each_with_object([]) do |data, memo|
        if data[:id]
          ids.push(data[:id])
        elsif data[:object].is_a? String
          elems = Fact.where(asset: data[:asset], predicate: data[:predicate],
                             object: data[:object])
        else
          elems = Fact.where(asset: data[:asset], predicate: data[:predicate],
                             object_asset: data[:object_asset])
        end
        memo.concat(elems) if elems
      end.concat(Fact.where(id: ids))
      _instances_deletion(Fact, modified_list) do
        _fact_operations('removeFacts', step, modified_list) if with_operations
      end
    end

    def _asset_group_building_operations(action_type, step, asset_groups)
      asset_groups.map do |asset_group|
        Operation.new(action_type: action_type, metadata_transaction: step, object: asset_group.uuid)
      end
    end

    def _asset_group_operations(action_type, step, asset_group_assets)
      asset_group_assets.map do |asset_group_asset, _index|
        Operation.new(action_type: action_type, metadata_transaction: step,
                      asset: asset_group_asset.asset, object: asset_group_asset.asset_group.uuid)
      end
    end

    def _asset_operations(action_type, step, assets)
      assets.map do |asset, _index|
        # refer = (action_type == 'deleteAsset' ? nil : asset)
        Operation.new(action_type: action_type, metadata_transaction: step, object: asset.uuid)
      end
    end

    def listening_to_predicate?(predicate)
      predicate == 'parent'
    end

    def _fact_operations(action_type, step, facts)
      modified_assets = []
      operations = facts.map do |fact|
        modified_assets.push(fact.object_asset) if listening_to_predicate?(fact.predicate)
        Operation.new(action_type: action_type, metadata_transaction: step,
                      asset: fact.asset, predicate: fact.predicate, object: fact.object,
                      object_asset: fact.object_asset)
      end
      modified_assets.flatten.compact.uniq.each(&:touch)
      operations
    end

    def all_values_are_new_records(hash)
      hash.values.all? do |value|
        (value.respond_to?(:new_record?) && value.new_record?)
      end
    end

    def _instance_builder_for_import(klass, params_list)
      instances = params_list.map do |params_for_instance|
        if params_for_instance.is_a?(klass)
          params_for_instance if params_for_instance.new_record?
        elsif all_values_are_new_records(params_for_instance) ||
              !klass.exists?(params_for_instance)
          klass.new(params_for_instance)
        end
      end.compact.uniq
      instances.each do |instance|
        instance.run_callbacks(:save) { false }
        instance.run_callbacks(:create) { false }
      end
      return unless instances && !instances.empty?

      klass.import(instances)
      # import does not return the ids for the instances, so we need to reload
      # again. Uuid is the only identificable attribute set
      klass.synchronize(instances, [:uuid]) if klass == Asset
      yield instances
    end

    def _instances_deletion(klass, instances)
      operations = block_given? ? yield(instances) : instances
      instances = instances.flatten
      ids_to_remove = instances.map(&:id).compact.uniq

      klass.where(id: ids_to_remove).delete_all if ids_to_remove && !ids_to_remove.empty?
      operations
    end
  end
end
