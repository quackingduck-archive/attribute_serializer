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
    if object.respond_to? :collect
      object.collect { |o| generate_single(o.class, context_name, o) }
    else
      generate_single(object.class, context_name, object)
    end
  end

  def generate_single(klass, context_name, object)
    context = context_for([klass, context_name])
    raise ArgumentError, "no contextual attributes setup for #{klass}:#{context_name}" unless context
    context.generate(object)
  end

  def context_for(key)
    closest_context_match = contexts.keys.select do |klass,context_name|
      key.first.ancestors.include?(klass) && key.last == context_name
    end.min_by { |(klass, _)| key.first.ancestors.index(klass) }

    contexts[closest_context_match]
  end

end

# The interface
#
# A default formatter:
#
#   AttributeSerializer BlogPost, %w(id created_at title body) do
#     def body
#       Rdiscount.new(formateee.body).to_html
#     end
#   end
#
# Then call with:
#
#   AttributeSerializer @post
#
# You can also define other formatters
#
#   AttributeSerializer BlogPost, :summary, %w(id created_at title)
#
# And you AttributeSerializer can produce formatted collections:
#
#   AttributeSerializer @posts, :summary
#
def AttributeSerializer(*args, &blk)
  if args.first.is_a?(Class)
    klass, context_name, attribs = (args.size == 3) ? args : [args[0], :default, args[1]]
    AttributeSerializer.add_context_set klass, context_name, attribs, &blk
  else
    AttributeSerializer.generate(args[1] || :default, args[0])
  end
end