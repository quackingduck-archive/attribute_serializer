require 'delegate'
require 'active_support/ordered_hash'

module Formatabator
  
  class ContextSet
        
    def initialize(klass, contexts, &delegate_methods)
      @contexts = contexts
      @delegate_class = DelegateClass(klass)
      @delegate_class.class_eval do
        def formatee; __getobj__ end
        def id; formatee.id end # DelegateClass was written before object_id became the new world order
      end
      @delegate_class.class_eval(&delegate_methods) if delegate_methods
    end
        
    def generate(context_name, object)
      @delegate = @delegate_class.new(object)
      ActiveSupport::OrderedHash.new.tap do |h|
        @contexts[context_name].each do |attrib|
          h[attrib.to_s] = @delegate.send(attrib) 
        end
      end
    end
    
  end
  
  extend self
  
  def context_sets
    @context_sets ||= {}
  end
  
  def add_context_set(klass, contexts, &delegate_methods)
    context_sets[klass] = ContextSet.new klass, contexts, &delegate_methods
  end
  
  def generate(context_name, object)
    if object.is_a?(Array)
      object.map { |o| generate_single(o.class, context_name, o) }
    else
      generate_single(object.class, context_name, object)
    end
  end
  
  def generate_single(klass, context_name, object)
    raise ArgumentError, "no contextual attributes setup for #{klass}" unless @context_sets.keys.include?(klass)
    context_sets[klass].generate(context_name,object)
  end
  
end

# A user interface. Parses a number of intuitive argument options
def Formatabator(arg1, arg2 = nil, &blk)
  if arg1.is_a?(Class)
    raise ArgumentError, "the second arg must be a hash of contexts and their attributes" unless arg2.is_a?(Hash)
    Formatabator.add_context_set(arg1,arg2,&blk)
  else
    Formatabator.generate(arg2 || :default, arg1)
  end
end