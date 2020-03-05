# frozen_string_literal: true

class MockedModel
  class << self
    attr_writer :attrs
  end

  class << self
    attr_reader :attrs
  end

  def attributes
    self.class.attrs.each_with_object({}) do |key, memo|
      memo[key] = send(key)
    end
  end

  def self.instances
    @instances ||= []
  end

  def self.attributes(params)
    self.attrs = params
    params.each { |k| attr_accessor k }
  end

  def initialize(params = nil)
    self.class.instances.push(self)
    return if params.nil?

    self.class.attrs.each { |k| send(:"#{k}=", params[k]) }
  end

  def self.find_by(params)
    where(params).first
  end

  def self.where(params)
    instances.select do |instance|
      params.keys.all? { |k| instance.send(k) == params[k] }
    end
  end

  def save
    true
  end

  def save!; end

  def new_record?
    true
  end
end
