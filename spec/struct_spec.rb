require 'spec_helper'
require 'parametric/struct'

describe Parametric::Struct do
  let(:friend_class) do
    Class.new do
      include Parametric::Struct

      schema do
        field(:name).type(:string).present
        field(:age).type(:integer)
      end
    end
  end
  let(:klass) do
    Class.new.tap do |cl|
      cl.send(:include, Parametric::Struct)

      cl.schema do |sc, _|
        sc.field(:title).type(:string).present
        sc.field(:friends).type(:array).default([]).schema friend_class
      end
    end
  end

  it "works" do
    new_instance = klass.new
    expect(new_instance.title).to eq ''
    expect(new_instance.friends).to eq []
    expect(new_instance.valid?).to be false
    expect(new_instance.errors['$.title']).not_to be_nil

    instance = klass.new({
      title: 'foo',
      friends: [
        {name: 'Ismael', age: 40},
        {name: 'Joe', age: 39},
      ]
    })

    expect(instance.title).to eq 'foo'
    expect(instance.friends.size).to eq 2
    expect(instance.friends.first.name).to eq 'Ismael'
    expect(instance.friends.first).to be_a friend_class

    # Hash access with #[]
    expect(instance[:title]).to eq instance.title
    expect(instance[:friends].first[:name]).to eq instance.friends.first.name

    invalid_instance = klass.new({
      friends: [
        {name: 'Ismael', age: 40},
        {age: 39},
      ]
    })

    expect(invalid_instance.valid?).to be false
    expect(invalid_instance.errors['$.title']).not_to be_nil
    expect(invalid_instance.errors['$.friends[1].name']).not_to be_nil
    expect(invalid_instance.friends[1].errors['$.name']).not_to be_nil
  end

  it 'supports #structure' do
    st = klass.schema.structure
    expect(st[:title][:type]).to eq(:string)
    expect(st[:friends][:structure][:age][:type]).to eq(:integer)
  end

  it 'supports #walk' do
    output = klass.schema.walk(:type).output
    expect(output[:title]).to eq(:string)
    expect(output[:friends][0][:name]).to eq(:string)
  end

  it "is inmutable by default" do
    klass = Class.new do
      include Parametric::Struct

      schema do
        field(:title).type(:string).present
        field(:friends).type(:array).default([])
        field(:friend).type(:object)
      end
    end

    instance = klass.new
    expect {
      instance.title = "foo"
    }.to raise_error NoMethodError

    expect {
      instance.friends << 1
    }.to raise_error RuntimeError
  end

  it "works with anonymous nested schemas" do
    klass = Class.new do
      include Parametric::Struct

      schema do
        field(:title).type(:string).present
        field(:friends).type(:array).schema do
          field(:age).type(:integer)
        end
      end
    end

    instance = klass.new({
      title: 'foo',
      friends: [
        {age: 10},
        {age: 39},
      ]
    })

    expect(instance.title).to eq 'foo'
    expect(instance.friends.size).to eq 2
    expect(instance.friends.first.age).to eq 10
  end

  it "wraps regular schemas in structs" do
    friend_schema = Parametric::Schema.new do
      field(:name)
    end

    klass = Class.new do
      include Parametric::Struct

      schema do
        field(:title).type(:string).present
        field(:friends).type(:array).schema friend_schema
      end
    end

    instance = klass.new({
      title: 'foo',
      friends: [{name: 'Ismael'}]
    })

    expect(instance.friends.first.name).to eq 'Ismael'
  end

  it "#to_h" do
    klass = Class.new do
      include Parametric::Struct

      schema do
        field(:title).type(:string).present
        field(:friends).type(:array).schema do
          field(:name).type(:string)
          field(:age).type(:integer).default(20)
        end
      end
    end

    instance = klass.new({
      title: 'foo',
      friends: [
        {name: 'Jane'},
        {name: 'Joe', age: '39'},
      ]
    })

    expect(instance.to_h).to eq({
      title: 'foo',
      friends: [
        {name: 'Jane', age: 20},
        {name: 'Joe', age: 39},
      ]
    })

    new_instance = klass.new(instance.to_h)
    expect(new_instance.title).to eq 'foo'

    # it returns a copy so we can't break things!
    data = new_instance.to_h
    data[:title] = 'nope'
    expect(new_instance.to_h[:title]).to eq 'foo'
  end

  it "works with inheritance" do
    klass = Class.new do
      include Parametric::Struct

      schema do
        field(:title).type(:string).present
        field(:friends).type(:array).schema do
          field(:name).type(:string)
          field(:age).type(:integer).default(20)
        end
      end
    end

    subclass = Class.new(klass) do
      schema do
        field(:email)
      end
    end

    instance = subclass.new(
      title: 'foo',
      email: 'email@me.com',
      friends: [
        {name: 'Jane', age: 20},
        {name: 'Joe', age: 39},
      ]
    )

    expect(instance.title).to eq 'foo'
    expect(instance.email).to eq 'email@me.com'
    expect(instance.friends.size).to eq 2
  end

  it "implements deep struct equality" do
    klass = Class.new do
      include Parametric::Struct

      schema do
        field(:title).type(:string).present
        field(:friends).type(:array).schema do
          field(:age).type(:integer)
        end
      end
    end

    s1 = klass.new({
      title: 'foo',
      friends: [
        {age: 10},
        {age: 39},
      ]
    })


    s2 = klass.new({
      title: 'foo',
      friends: [
        {age: 10},
        {age: 39},
      ]
    })

    s3 = klass.new({
      title: 'foo',
      friends: [
        {age: 11},
        {age: 39},
      ]
    })

    s4 = klass.new({
      title: 'bar',
      friends: [
        {age: 10},
        {age: 39},
      ]
    })

    expect(s1 == s2).to be true
    expect(s1 == s3).to be false
    expect(s1 == s4).to be false
  end

  it "#merge returns a new instance" do
    klass = Class.new do
      include Parametric::Struct

      schema do
        field(:title).type(:string).present
        field(:desc)
        field(:friends).type(:array).schema do
          field(:name).type(:string)
        end
      end
    end

    original = klass.new(
      title: 'foo',
      desc: 'no change',
      friends: [{name: 'joe'}]
    )

    copy = original.merge(
      title: 'bar',
      friends: [{name: 'jane'}]
    )

    expect(original.title).to eq 'foo'
    expect(original.desc).to eq 'no change'
    expect(original.friends.first.name).to eq 'joe'

    expect(copy.title).to eq 'bar'
    expect(copy.desc).to eq 'no change'
    expect(copy.friends.first.name).to eq 'jane'
  end

  describe '.new!' do
    it 'raises a useful exception if invalid data' do
      klass = Class.new do
        include Parametric::Struct

        schema do
          field(:title).type(:string).present
          field(:consumption).type(:object).present.schema do
            field(:type).present.options(%w[aaa bbb])
          end
        end
      end

      begin
        klass.new!(title: '')
      rescue Parametric::InvalidStructError => e
        expect(e.errors['$.title']).not_to be nil
        expect(e.errors['$.consumption']).not_to be nil
      end

      valid = klass.new!(title: 'foo', consumption: { type: 'aaa' })
      expect(valid.title).to eq 'foo'
    end
  end

  it 'works with Field#one_of(*schemas)' do
    sub1 = Parametric::Schema.new do
      field(:name).type(:string).present
    end

    sub2 = Parametric::Schema.new do
      field(:age).type(:integer).present
    end

    klass = Class.new do
      include Parametric::Struct

      schema do
        field(:user).type(:object).one_of(sub1, sub2)
      end
    end

    valid = klass.new!(user: { age: '20' })
    expect(valid.user.age).to eq 20
  end
end
