require 'spec_helper'
require 'parametric/struct'

describe Parametric::Struct do
  it "works" do
    friend_class = Class.new do
      include Parametric::Struct

      property(:name, :string).present
      property :age, :integer
    end

    klass = Class.new do
      include Parametric::Struct

      property(:title, :string).present
      property :friends, :array, of: friend_class
    end

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
  end

  it "is inmutable by default" do
    klass = Class.new do
      include Parametric::Struct

      property(:title, :string).present
      property :friends, :array
      property :friend, :object
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

      property(:title, :string).present
      property :friends, :array do
        property :age, :integer
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

  it "#to_h" do
    klass = Class.new do
      include Parametric::Struct

      property(:title, :string).present
      property :friends, :array do
        property :name, :string
        property(:age, :integer).default(20)
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
  end
end
