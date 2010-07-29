require 'delegate'
require 'active_support/ordered_hash'

# Implementation
module AttributeSerializer

  extend self # check it out, singleton

  class Context

    def initialize(klass, attribs, &delegate_methods)
      @attribs = attribs
      @delegate_class = DelegateClass(klass)
      @delegate_class.class_eval do
        def delegatee; __getobj__ end
        def id; formatee.id end # DelegateClass was written before object_id became the new world order
        alias_method :formatee, :delegatee # this was a stupid name
      end
      @delegate_class.class_eval(&delegate_methods) if delegate_methods
    end

    def generate(object)
      @delegate = @delegate_class.new(object)
      ActiveSupport::OrderedHash.new.tap do |h|
        @attribs.each do |attrib|
          h[attrib.to_s] = @delegate.send(attrib)
        end
      end
    end

  end

  def contexts
    @contexts ||= {}
  end

  def add_context_set(klass, context_name, attribs, &delegate_methods)
    key = [klass, context_name]
    contexts[key] = Context.new klass, attribs, &delegate_methods
  end

  def generate(context_name, object)
    hash_is_serializable = false
    if object.is_a?(Hash)
      hash_is_serializable = object.values.map {|o| context_for?(o.class, context_name)}.all?
      return object if context_name == :default && !hash_is_serializable
    end

    if hash_is_serializable
      object.inject(ActiveSupport::OrderedHash.new) do |hash, (key,obj)|
        hash[key.to_s] = generate_single(obj.class, context_name, obj)
        hash
      end
    elsif object.respond_to? :collect
      object.collect { |o| generate_single(o.class, context_name, o) }
    else
      generate_single(object.class, context_name, object)
    end
  end

  def generate_single(klass, context_name, object)
    return object if klass == String
    context = context_for(klass, context_name)
    raise ArgumentError, "no contextual attributes setup for #{klass}:#{context_name}" unless context
    context.generate(object)
  end

  def context_for(klass, context_name)
    closest_context_match = contexts.keys.select do |c,n|
      klass.ancestors.include?(c) && context_name == n
    end.min_by { |c, _| klass.ancestors.index(c) }

    contexts[closest_context_match]
  end

  def context_for?(klass, context_name=:default)
    !!AttributeSerializer.context_for(klass, context_name)
  end

end

# Public: Define a serializer or serialize an object or collection
#
# Examples
#
# Define a default serializer on your class:
#
#   AttributeSerializer BlogPost, %w(id created_at title body) do
#     def body
#       Rdiscount.new(formateee.body).to_html
#     end
#   end
#
# Then serialize and instance like:
#
#   AttributeSerializer @post
#
# You can also define other serializers:
#
#   AttributeSerializer BlogPost, :summary, %w(id created_at title)
#
# And serialize collections:
#
#   AttributeSerializer @posts, :summary
#
# AttributeSerializer returns an OrderedHash as the serialization, it's up to
# you to call #to_json or #to_yaml on that object
#
# Returns an OrderedHash serialization when given an object or collection
def AttributeSerializer(*args, &blk)
  if args.first.is_a?(Class)
    klass, context_name, attribs = (args.size == 3) ? args : [args[0], :default, args[1]]
    AttributeSerializer.add_context_set klass, context_name, attribs, &blk
  else
    AttributeSerializer.generate(args[1] || :default, args[0])
  end
end