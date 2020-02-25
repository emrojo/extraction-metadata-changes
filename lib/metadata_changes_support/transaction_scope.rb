module MetadataChangesSupport
  module TransactionScope
    class ModelAccessor
      attr_reader :result_set

      def initialize(klass, updates)
        @klass = klass
        @updates = updates
        @result_set = @klass
        @joins = []
      end

      def _disjoint_lists
        {
          fact: {
            create: @updates.facts_to_add,
            delete: @updates.facts_to_destroy
          },
          asset_group: {
            create: @updates.asset_groups_to_create,
            delete: @updates.asset_groups_to_destroy
          },
          asset_group_asset: {
            create: @updates.assets_to_add,
            delete: @updates.assets_to_remove
          },
          asset: {
            create: @updates.assets_to_create,
            delete: @updates.assets_to_destroy
          }
        }
      end

      def joins(join)
        @joins.push(join)
        @result_set = @result_set.joins(join)
        self
      end

      def _result_set_from_database(opts)
        if (result_set.respond_to?(:superclass) && (result_set.superclass == ActiveRecord::Base))
          @result_set = result_set.where(opts)
        else
          @result_set = result_set.to_a.concat(@klass.where(opts))
        end
      end

      # Filters out assets that do not complie to the conditions expressed in the opts anymore
      def _filter_removed_entries(opts)
        if (@klass==Asset)
          if @updates.to_h[:delete_assets]
            selected_elements=result_set.to_a.select{|a| @updates.to_h[:delete_assets].include?(a.uuid)}
            @result_set=result_set.to_a - selected_elements
          end
          if @updates.to_h[:remove_facts]
            if opts[:facts]
              selected_elements = result_set.select do |element|
                @updates.to_h[:remove_facts].any? do |triple|
                  object_asset = Asset.find(opts[:facts][:object_asset_id]) if opts[:facts][:object_asset_id]

                  (
                    (triple[0]==element.uuid) &&
                    (opts[:facts][:predicate] == triple[1]) &&
                    (opts[:facts][:object] == triple[2]) || (object_asset.uuid == triple[2])
                  )
                end
              end
              @result_set=result_set.to_a - selected_elements
            end
          end
        end
      end

      def _append_added_entries(opts)
        selected_elements = _select_by(opts)
        @result_set=result_set.to_a.concat(selected_elements) if selected_elements.length > 0
      end

      def where(opts)
        _result_set_from_database(opts)

        _filter_removed_entries(opts)

        _append_added_entries(opts)

        @result_set
      end

      def exists?(opts)
        (where(opts).size > 0)
      end

      def find(id)
        where(id: id).first
      end

      def find_by(opts)
        where(opts)
      end

      private

      def _disjoint_list_for(type)
        model = @klass.to_s.downcase.to_sym
        _disjoint_lists[model][type]
      end

      def _join_condition(elem, default_fkey_name=nil)
        default_fkey_name ||= @klass.to_s.downcase.to_sym
        rel={}
        rel[default_fkey_name] = elem
        rel
      end

      def _get_or_build_accessor(klass)
        return nil unless klass
        @accessors ||= {}
        @accessors[klass] = ModelAccessor.new(klass, @updates)
      end

      def _select_by(opts)
        _disjoint_list_for(:create).select do |a|
          opts.all? do |k,v|
            model_name = k.to_s.singularize.to_sym
            if (_disjoint_lists.has_key?(model_name) && (v.kind_of?(Hash)))
              class_name = model_name.to_s.classify.constantize
              accessor = _get_or_build_accessor(class_name)
              accessor.exists?(opts[k].merge(_join_condition(a)))
            else
              k_id = k.to_s.concat("_id").to_sym
              if a.respond_to?(k)
                a.send(k)==v
              elsif (a.respond_to?(k_id) && (k_id != :object_id))
                a.send(k_id)
              elsif (a.kind_of?(Hash) && a.has_key?(k))
                a[k]==v
              elsif (a.kind_of?(Hash) && a.has_key?(k_id))
                a[k_id]==v.id
              else
                false
              end
            end
          end
        end
      end
    end

    def transaction_scope(klass)
      raise 'Unsupported transaction scope class' unless klass == Asset
      @transaction_scopes ||= {}
      @transaction_scopes[klass.to_s] ||= ModelAccessor.new(klass, self)
    end

  end
end
