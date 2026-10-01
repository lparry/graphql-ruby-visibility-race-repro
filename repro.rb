require "graphql"

class Icon < GraphQL::Schema::Object
  field :name, String
end

class Image < GraphQL::Schema::Object
  field :url, String
end

class Avatar < GraphQL::Schema::Union
  possible_types Icon, Image
end

class Query < GraphQL::Schema::Object
  field :avatar, Avatar
end

class MySchema < GraphQL::Schema
  query Query
  use GraphQL::Schema::Visibility, preload: true
end

visibility = MySchema.visibility
load_started = Queue.new
resume_load = Queue.new

GraphQL::Schema::Visibility::Visit.prepend(Module.new do
  define_method(:visit_each) do |types: entry_point_types, directives: entry_point_directives|
    if types.any?
      load_started << true
      resume_load.pop
    end

    super(types:, directives:)
  end
end)

puts "Starting visibility reference-index traversal."
puts "The test pauses that traversal, then reads the index from another thread."

loader = Thread.new { visibility.all_references }
load_started.pop
during = visibility.all_references[Icon].size
puts "While traversal is paused, Icon reference count is #{during} (expected 0: index is incomplete)."

resume_load << true
loader.value
after = visibility.all_references[Icon].size

unless during.zero? && after == 1
  abort "RACE NOT REPRODUCED: expected Icon's reference count to change from 0 to 1."
end

puts "After traversal completes, Icon reference count is #{after} (expected 1: Avatar references Icon)."
puts "RACE REPRODUCED: the concurrent read returned before the reference index was ready."
