require 'spec_helper'
require "parametric/dsl"

describe "classes including DSL module" do
  class Parent
    include Parametric::DSL

    schema :extras, search_type: :string do |opts|
      field(:search).policy(opts[:search_type])
    end

    schema(age_type: :integer) do |opts|
      field(:title).policy(:string)
      field(:age).policy(opts[:age_type])
    end
  end

  class Child < Parent
    schema :extras do
      field(:query).type(:string)
    end

    schema(age_type: :string) do
      field(:description).policy(:string)
    end
  end

  class GrandChild < Child
    schema :extras, search_type: :integer

    schema(age_type: :integer)
  end

  describe "#schema" do
    let(:input) {
      {
        title: "A title",
        age: 38,
        description: "A description"
      }
    }

    it "merges parent's schema into child's" do
      parent_output = Parent.schema.resolve(input).output
      child_output = Child.schema.resolve(input).output

      expect(parent_output.keys).to match_array([:title, :age])
      expect(parent_output[:title]).to eq "A title"
      expect(parent_output[:age]).to eq 38

      expect(child_output.keys).to match_array([:title, :age, :description])
      expect(child_output[:title]).to eq "A title"
      expect(child_output[:age]).to eq "38"
      expect(child_output[:description]).to eq "A description"

      # named schema
      parent_output = Parent.schema(:extras).resolve(search: 10, query: 'foo').output
      child_output = Child.schema(:extras).resolve(search: 10, query: 'foo').output

      expect(parent_output.keys).to match_array([:search])
      expect(parent_output[:search]).to eq "10"
      expect(child_output.keys).to match_array([:search, :query])
      expect(child_output[:search]).to eq "10"
      expect(child_output[:query]).to eq "foo"
    end

    it "inherits options" do
      grand_child_output = GrandChild.schema.resolve(input).output

      expect(grand_child_output.keys).to match_array([:title, :age, :description])
      expect(grand_child_output[:title]).to eq "A title"
      expect(grand_child_output[:age]).to eq 38
      expect(grand_child_output[:description]).to eq "A description"

      # named schema
      grand_child_output = GrandChild.schema(:extras).resolve(search: "100", query: "bar").output
      expect(grand_child_output.keys).to match_array([:search, :query])
      expect(grand_child_output[:search]).to eq 100
    end
  end

  describe "inheriting schema policy" do
    let!(:a) {
      Class.new do
        include Parametric::DSL

        schema.policy(:present) do
          field(:title).policy(:string)
        end
      end
    }

    let!(:b) {
      Class.new(a)
    }

    it "inherits policy" do
      results = a.schema.resolve({})
      expect(results.errors["$.title"]).not_to be_empty

      results = b.schema.resolve({})
      expect(results.errors["$.title"]).not_to be_empty
    end
  end

  describe "overriding schema policy" do
    let!(:a) {
      Class.new do
        include Parametric::DSL

        schema.policy(:present) do
          field(:title).policy(:string)
        end
      end
    }

    let!(:b) {
      Class.new(a) do
        schema.policy(:declared)
      end
    }

    it "does not mutate parent schema" do
      results = a.schema.resolve({})
      expect(results.errors).not_to be_empty

      results = b.schema.resolve({})
      expect(results.errors).to be_empty
    end
  end

  describe "removes fields defined in the parent class" do
    let!(:a) {
      Class.new do
        include Parametric::DSL

        schema do
          field(:title).policy(:string)
        end
      end
    }

    let!(:b) {
      Class.new(a) do
        schema.ignore(:title) do
          field(:age)
        end
      end
    }

    it "removes inherited field from child class" do
      results = a.schema.resolve({title: "Mr.", age: 20})
      expect(results.output).to eq({title: "Mr."})

      results = b.schema.resolve({title: "Mr.", age: 20})
      expect(results.output).to eq({age: 20})
    end
  end
end

