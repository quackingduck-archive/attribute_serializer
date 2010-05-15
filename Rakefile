task :default => [:test]

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gs|
    gs.name     = "attribute_serializer"
    gs.homepage = "http://github.com/quackingduck/attribute_serializer"
    gs.summary  = "Takes an object, serializes the attributes to an ordered hash based on a pre-defined schema"
    gs.email    = "myles@myles.id.au"
    gs.authors  = ["Myles Byrne"]
    gs.add_development_dependency('exemplor', '>= 3000.1.0')
    gs.files.include %(lib/attribute_serializer.rb) # jewler used to include files in lib automatically, what happened?
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Install jeweler to build gem"
end

task :test do
  ruby '-rubygems', "examples.rb"
end