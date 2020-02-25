require 'securerandom'
require 'google_hash'

module MetadataChangesSupport
  class DisjointList
    SEED_FOR_UNIQUE_IDS = Random.rand(1000)
    MAX_DEEP_UNIQUE_ID = 3

    include Enumerable

    attr_accessor :location_for_unique_id
    attr_accessor :disjoint_lists
    attr_accessor :list
    attr_reader :name

    DISABLED_NAME="DISABLED"

    def initialize(list)
      @name = "object_id_#{object_id}"

      # Replace with a normal hash if we want to stop using it
      @location_for_unique_id = GoogleHashDenseLongToRuby.new

      @list = []
      @disjoint_lists = [self]
      list.each {|o| add(o)}
    end

    def add_disjoint_list(disjoint_list)
      disjoints = (disjoint_list.disjoint_lists - disjoint_lists)
      disjoint_lists.concat(disjoints).uniq

      disjoints.each do |disjoint|
        _synchronize_with_list(disjoint)

        disjoint.location_for_unique_id = location_for_unique_id
        disjoint.disjoint_lists = disjoint_lists
      end
    end

    def store_for(element)
      _store_for(unique_id_for_element(element))
    end

    def _store_for(unique_id)
      store_name = location_for_unique_id[unique_id]
      return nil if store_name.nil? || store_name == DISABLED_NAME
      @disjoint_lists.select{|l| l.name == store_name}.first
    end


    def enabled?(element)
      !store_for(element).nil?
    end

    def disabled?(element)
      disabled_key?(unique_id_for_element(element))
    end

    def disabled_key?(key)
      @location_for_unique_id[key] == DISABLED_NAME
    end

    def enabled_in_other_list?(element)
      enabled?(element) && !include?(element)
    end

    def include?(element)
      include_key?(unique_id_for_element(element))
    end

    def include_key?(key)
      @location_for_unique_id[key] == name
    end

    def remove(element)
      unique_id = unique_id_for_element(element)
      remove_from_raw_list_by_id(unique_id)
      @location_for_unique_id.delete(unique_id)
    end

    def remove_from_raw_list_by_id(unique_id)
      @list.delete_if do |a|
        unique_id_for_element(a) == unique_id
      end
    end

    def length
      @list.length
    end

    def each(&block)
      @list.each(&block)
    end

    def [](index)
      @list[index]
    end

    def flatten
      @list.flatten
    end

    def uniq!
      @list.uniq!
    end

    def <<(element)
      if element.kind_of?(Array)
        element.each{|e| add(e)}
      else
        add(element)
      end
    end

    def concat(element)
      if element.kind_of?(Array)
        element.each{|e| add(e)}
      else
        add(element)
      end
    end

    def push(element)
      add(element)
    end

    def add(element)
      return concat_disjoint_list(element) if element.kind_of?(MetadataChangesSupport::DisjointList)
      if enabled_in_other_list?(element)
        disable(element)
      elsif include?(element)
        # It is already in our list, so we do not add it again
        return false
      else
        enable(element)
      end
      self
    end

    def sum_function_for(value)
      return value.hash
      # Value to create checksum and seed
      #XXhash.xxh32(value, SEED_FOR_UNIQUE_IDS)
    end

    def unique_id_for_element(element)
      return _unique_id_for_element(element, 0)
    end

    def concat_disjoint_list(disjoint_list)
      disjoint_list.location_for_unique_id.keys.each do |key|
        if disjoint_list.disabled_key?(key)
          _disable(key)
        end
      end
      disjoint_list.to_a.each {|val| add(val)}
      self
    end

    def merge(disjoint_list)
      disjoint_list.location_for_unique_id.keys.each do |key|
        if (!disjoint_list.include_key?(key) || disjoint_list.disabled_key?(key))
          _disable(key)
        end
      end
      disjoint_list.to_a.each {|val| add(val)}
      self
    end

    def enable(element)
      return if disabled?(element)
      unique_id = unique_id_for_element(element)
      # Is not in any of the lists so we can add it
      if (element.kind_of?(Enumerable) && (!element.kind_of?(Hash)))
        @list.concat(element)
      else
        @list.push(element)
      end
      @location_for_unique_id[unique_id]=name
    end

    def disable(element)
      _disable(unique_id_for_element(element))
    end

    protected

    def _synchronize_with_list(disjoint_list)
      disjoint_list.location_for_unique_id.keys.each do |key|
        unless (location_for_unique_id[key] == DISABLED_NAME)
          # If my disjoint lists do not have the element
          if location_for_unique_id[key].nil?
            location_for_unique_id[key]=disjoint_list.location_for_unique_id[key]
            if location_for_unique_id[key] == DISABLED_NAME
              _disable(key)
            end
          else
            # If my lists have the element alredy
            if location_for_unique_id[key] != disjoint_list.location_for_unique_id[key]
              _disable(key)
            end
          end
        end
      end
    end

    def _disable(unique_id)
      store = _store_for(unique_id)
      store.remove_from_raw_list_by_id(unique_id) if store
      location_for_unique_id[unique_id]=DISABLED_NAME
    end

    def _unique_id_for_element(element, deep=0)
      return sum_function_for(SecureRandom.uuid) if deep==MAX_DEEP_UNIQUE_ID
      if element.kind_of?(String)
        sum_function_for(element)
      elsif (element.respond_to?(:uuid) && (!element.uuid.nil?))
        sum_function_for(element.uuid)
      elsif (element.respond_to?(:id) && !element.id.nil?)
        sum_function_for("#{element.class.to_s}_#{element.id.to_s}")
      elsif element.kind_of?(Hash)
        if (element.has_key?(:uuid) && (!element[:uuid].nil?))
          sum_function_for(element[:uuid])
        elsif (element.has_key?(:predicate))
          _unique_id_for_fact(element)
        else
          sum_function_for(element.keys.dup.concat(element.values.map{|val| _unique_id_for_element(val, deep+1)}).join(""))
        end
      elsif element.kind_of?(Enumerable)
        sum_function_for(element.map{|o| _unique_id_for_element(o, deep+1)}.join(""))
      else
        sum_function_for(element.to_s)
      end
    end

    def _unique_id_for_fact(element)
      sum_function_for([
        (element[:asset_id] || element[:asset].id || element[:asset].object_id),
        element[:predicate],
        (element[:object] || element[:object_asset_id] || element[:object_asset].id || element[:object_asset].object_id)
      ].join('_'))
    end

  end
end
