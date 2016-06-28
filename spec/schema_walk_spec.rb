require 'spec_helper'

describe 'Schema#walk' do
  let(:schema) do
    Parametric::Schema.new do
      field(:title).meta(example: 'a title', label: 'custom title')
      field(:tags).type(:array).meta(example: ['tag1', 'tag2'], label: 'comma-separated tags')
      field(:friends).type(:array).schema do
        field(:name).meta(example: 'a friend', label: 'friend full name')
        field(:age).meta(example: 34, label: 'age')
      end
    end
  end

  it "recursively walks the schema and collects meta data" do
    results = schema.walk(:label)
    expect(results.output).to eq({
      title: 'custom title',
      tags: 'comma-separated tags',
      friends: [
        {
          name: 'friend full name',
          age: 'age'
        }
      ]
    })
  end

  it "works with blocks" do
    results = schema.walk{|field| field.meta_data[:example]}
    expect(results.output).to eq({
      title: 'a title',
      tags: ['tag1', 'tag2'],
      friends: [
        {
          name: 'a friend',
          age: 34
        }
      ]
    })
  end
end
