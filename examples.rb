require 'exemplor'
require 'lib/attribute_serializer'

def OHash &blk
  ActiveSupport::OrderedHash.new.tap(&blk)
end

Class.class_eval do
  def create(hash)
    self.new.tap do |o| hash.each { |k,v| o.send("#{k}=", v) } end
  end
end

eg.helpers do

  def self.mem(name, &blk)
    define_method name do
      instance_variable_get("@#{name}") or
      instance_variable_set("@#{name}", blk.call)
    end
  end

  mem :article_class do
    Class.new { attr_accessor :id, :title, :body, :author }
  end

  mem :author_class do
    Class.new { attr_accessor :name, :email }
  end

end

eg "Serializable object" do
  AttributeSerializer article_class, %w(id title body)

  article = article_class.create(
    :id    => 1,
    :title => "Contextual Attributes",
    :body  => "The layer you've always wanted for generating your json"
  )

  expected_hash = OHash do |h|
    h['id']    = 1
    h['title'] = "Contextual Attributes"
    h['body']  = "The layer you've always wanted for generating your json"
  end

  # AttributeSerializer(article) is equivalent to:
  # AttributeSerializer(article,:default)
  Assert(AttributeSerializer(article) == expected_hash)
end

eg "Serializable subclass object" do
  subclass = Class.new(article_class) { attr_accessor :photo_url }

  # AttributeSerializer only defined for *ancestor class*
  AttributeSerializer article_class, %w(id title body)

  photo_post = subclass.create(
    :id        => 1,
    :title     => "Contextual Attributes",
    :body      => "The layer you've always wanted for generating your json",
    :photo_url => "http://foobar.com/lemonparty.jpg"
  )

  expected_hash = OHash do |h|
    h['id']    = 1
    h['title'] = "Contextual Attributes"
    h['body']  = "The layer you've always wanted for generating your json"
  end

  # Serialization on instance of *subclass*
  Assert(AttributeSerializer(photo_post) == expected_hash)

  # define AttributeSerializer for the actual class
  AttributeSerializer subclass, %w(id title body photo_url)

  expected_hash['photo_url'] = "http://foobar.com/lemonparty.jpg"

  # Serialization on instance of subclass now that there's a serializer for it
  Assert(AttributeSerializer(photo_post) == expected_hash)
end

eg "Object with nested serializable attribute" do
  article_class = Class.new { attr_accessor :id, :author }

  AttributeSerializer author_class, %w(name email)
  AttributeSerializer article_class, %w(id author) do
    # no implicit support for nesting, intentionally
    def author
      AttributeSerializer delegatee.author
    end
  end

  article = article_class.create(
    :id     => 1,
    :author => author_class.create(
      :name  => "Myles",
      :email => "myles@"
    )
  )

  expected_hash = OHash do |h|
    h['id']     = 1
    h['author'] = OHash do |h|
      h['name']  = "Myles"
      h['email'] = "myles@"
    end
  end

  Assert(AttributeSerializer(article) == expected_hash)
end

eg "Array of serializable objects" do
  AttributeSerializer author_class, %w(name email)

  array = [
    author_class.create(:name => "Myles",   :email => 'myles@'),
    author_class.create(:name => "Gabriel", :email => 'gabriel@')
  ]

  expected_array = [
    OHash { |h| h['name'] = "Myles";   h['email'] = 'myles@' },
    OHash { |h| h['name'] = "Gabriel"; h['email'] = 'gabriel@' }
  ]

  Assert(AttributeSerializer(array) == expected_array)
end

eg "Non-default serializer" do
  AttributeSerializer article_class, :summary, %w(id title)

  article = article_class.create(
    :id    => 1,
    :title => "Contextual Attributes",
    :body  => "The layer you've always wanted for generating your json"
  )

  expected_hash = OHash do |h|
    h['id'] = 1
    h['title'] = "Contextual Attributes"
  end

  Assert(AttributeSerializer(article, :summary) == expected_hash)
end

eg "Hashes are passed straight through" do
  Assert(AttributeSerializer({ :foo => 'bar' }) == { :foo => 'bar' })
end