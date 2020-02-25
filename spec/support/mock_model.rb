require 'pry'
class MockModel

  def self.attrs=(params)
    @attrs = params
  end

  def self.attrs
    @attrs
  end

  def self.instances
    @instances ||= []
  end

  def self.attributes(params)
    self.attrs = params
    params.each {|k| attr_accessor k }
  end

  def initialize(params=nil)
    self.class.instances.push(self)
    return if params.nil?
    self.class.attrs.each{|k| send(:"#{k}=",params[k]) }
  end

  def self.find_by(params)
    list = where(params)
    return list.first if list.length == 1
    list
  end

  def self.where(params)
    self.instances.select do |instance|
      params.keys.all? {|k| instance.send(k) == params[k] }
    end
  end

  def save
    true
  end

  def new_record?
    true
  end

end
