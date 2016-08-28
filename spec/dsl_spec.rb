require 'spec_helper'
require "parametric/dsl"

describe "classes including DSL module" do
  let!(:parent) do
    Class.new do
      include Parametric::DSL

      schema(age_type: :integer) do |opts|
        field(:title).policy(:string)
        field(:age).policy(opts[:age_type])
      end
    end
  end

  let!(:child) do
    Class.new(parent) do
      schema(age_type: :string) do
        field(:description).policy(:string)
      end
    end
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
      parent_output = parent.schema.resolve(input).output
      child_output = child.schema.resolve(input).output

      expect(parent_output.keys).to match_array([:title, :age])
      expect(parent_output[:title]).to eq "A title"
      expect(parent_output[:age]).to eq 38

      expect(child_output.keys).to match_array([:title, :age, :description])
      expect(child_output[:title]).to eq "A title"
      expect(child_output[:age]).to eq "38"
      expect(child_output[:description]).to eq "A description"
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
      Class.new(a) do
      end
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

