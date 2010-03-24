require 'riot'
require 'lib/attribute_serializer'

def OHash &blk
  ActiveSupport::OrderedHash.new.tap(&blk)
end

Class.class_eval do
  def create(hash)
    self.new.tap do |o| hash.each { |k,v| o.send("#{k}=", v) } end
  end
end

class Author
  attr_accessor :name, :email
end

class BlogPost
  attr_accessor :id, :title, :body, :author
end

class PhotoBlogPost < BlogPost
  attr_accessor :photo_url
end

context "Formatable object, default formator" do
  setup do
    AttributeSerializer BlogPost, %w(id title body)

    BlogPost.create(
      :id    => 1,
      :title => "Contextual Attributes",
      :body  => "The layer you've always wanted for generating your json"
    )
  end

  asserts('produces the correct hash') do
    AttributeSerializer topic # equivalent to AttributeSerializer(topic,:default)
  end.equals(OHash { |h|
    h['id']    = 1
    h['title'] = "Contextual Attributes"
    h['body']  = "The layer you've always wanted for generating your json"
  })
end

context "Formatable subclass object, default formator" do
  setup do
    # define AttributeSerializer for *ancestor class*
    AttributeSerializer BlogPost, %w(id title body)

    @post = PhotoBlogPost.create(
      :id        => 1,
      :title     => "Contextual Attributes",
      :body      => "The layer you've always wanted for generating your json",
      :photo_url => "http://foobar.com/lemonparty.jpg"
    )
  end

  asserts('produces the correct hash') do
    AttributeSerializer topic # equivalent to AttributeSerializer(topic,:default)
  end.equals(OHash { |h|
    h['id']    = 1
    h['title'] = "Contextual Attributes"
    h['body']  = "The layer you've always wanted for generating your json"
  })

  context "with subclass serializer" do
    setup do
      AttributeSerializer PhotoBlogPost, %w(id title body photo_url)
      @post
    end

    asserts('produces the correct hash') do
      AttributeSerializer topic # equivalent to AttributeSerializer(topic,:default)
    end.equals(OHash { |h|
      h['id']        = 1
      h['title']     = "Contextual Attributes"
      h['body']      = "The layer you've always wanted for generating your json"
      h['photo_url'] = "http://foobar.com/lemonparty.jpg"
    })
  end

end

context "Nested formatable attrib" do
  setup do
    AttributeSerializer Author, %w(name email)

    AttributeSerializer BlogPost, %w(id author) do
      # no implicit support for nesting, intentionally
      def author
        AttributeSerializer formatee.author
      end
    end

    BlogPost.create(
      :id     => 1,
      :author => Author.create(
        :name  => "Myles",
        :email => "myles@"
      )
    )
  end

  asserts('produces the correct hash') { AttributeSerializer(topic, :default) }.
  equals(OHash { |h|
    h['id']     = 1
    h['author'] = OHash do |h|
      h['name']  = "Myles"
      h['email'] = "myles@"
    end
  })
end

context "Array of formatable objects" do
  setup do
    AttributeSerializer Author, %w(name email)
    [ Author.create(:name => "Myles",   :email => 'myles@'),
      Author.create(:name => "Gabriel", :email => 'gabriel@') ]
  end

  asserts('produces the correct hash') { AttributeSerializer(topic, :default) }.
  equals([
    OHash { |h| h['name'] = "Myles";   h['email'] = 'myles@' },
    OHash { |h| h['name'] = "Gabriel"; h['email'] = 'gabriel@' }
  ])
end

context "A non-default formatter" do
  setup do
    AttributeSerializer BlogPost, :summary, %w(id title)
    BlogPost.create(
      :id    => 1,
      :title => "Contextual Attributes",
      :body  => "The layer you've always wanted for generating your json"
    )
  end

  asserts('produces the correct hash') { AttributeSerializer(topic, :summary) }.
  equals(
    OHash { |h| h['id'] = 1; h['title'] = "Contextual Attributes" }
  )
end

context "Hashes are passed straight through" do
  setup { AttributeSerializer({ :foo => 'bar' }) }
  
  asserts_topic.equals({:foo => 'bar'})
end