# frozen_string_literal: true

class MockedRelation
  def initialize(list)
    @list = list
  end

  def parent=(parent_instance)
    @parent_instance = parent_instance
  end

  def <<(instance)
    related = instance.dup
    related.asset = @parent_instance
    @list.push(related)
  end

  def with_predicate(pred)
    @list.select do |instance|
      instance.predicate == pred
    end
  end
end
