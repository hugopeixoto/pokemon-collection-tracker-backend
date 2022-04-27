# SPDX-FileCopyrightText: 2022 Hugo Peixoto <hugo.peixoto@gmail.com>
# SPDX-License-Identifier: AGPL-3.0-only

require 'sinatra'
require 'sinatra/jsonapi'
require 'securerandom'

class Database
  class <<self
    attr_reader :bags, :bag_cards

    def load
      @items = {
        "bag" => File.readlines("database/bags.jsonl").map { |bag| Bag.new(JSON.load(bag)) },
        "bag-card" => File.readlines("database/bag-cards.jsonl").map { |bc| BagCard.new(JSON.load(bc)) },
      }
    end

    def [](type)
      @items.fetch(type)
    end

    def save(type, item)
      position = @items.fetch(type).index { |e| e.id == item.id }

      if position.nil?
        @items.fetch(type) << item
      else
        @items[position] = item
      end

      File.write(
        "database/#{type}s.jsonl",
        @items.fetch(type).map { |item| "#{item.to_json}\n" }.join
      )
    end

    def delete(type, item)
      @items.fetch(type).filter! { |e| e.id != item.id }

      File.write(
        "database/#{type}s.jsonl",
        @items.fetch(type).map { |item| "#{item.to_json}\n" }.join
      )
    end
  end
end

class Bag
  attr_accessor :id, :category, :name

  def initialize(attrs)
    @id = attrs["id"] || SecureRandom.uuid
    @category = attrs["category"]
    @name = attrs["name"]
  end

  def to_json
    JSON.dump({ id: id, category: category, name: name })
  end

  def bag_cards
    Database["bag-card"].select { |bc| bc.bag_id == id }
  end

  def self.all
    Database["bag"]
  end

  def self.find(id)
    all.find { |bag| bag.id == id }
  end
end

class BagCard
  attr_accessor :id, :bag_id, :dbid, :modifiers

  def initialize(attrs)
    @id = attrs["id"] || SecureRandom.uuid
    @dbid = attrs["dbid"]
    @modifiers = attrs["modifiers"]
    @bag_id = attrs["bag-id"]
  end

  def to_json
    JSON.dump({ id: id, "bag-id": bag_id, dbid: dbid, modifiers: modifiers })
  end

  def bag
    Database["bag"].find { |bag| bag.id == bag_id }
  end

  def self.all
    Database["bag-card"]
  end

  def self.find(id)
    all.find { |e| e.id.to_s == id.to_s }
  end
end

class BagSerializer
  include JSONAPI::Serializer

  attribute :category
  attribute :name

  has_many :bag_cards
end

class BagCardSerializer
  include JSONAPI::Serializer

  attribute :dbid
  attribute :modifiers
  has_one :bag
end

Database.load

helpers do
  def role
    if env['HTTP_AUTHORIZATION'] == ENV['POKEMON_AUTH']
      :owner
    else
      nil
    end
  end
end

resource :bags, pkre: /[\da-f-]+/ do
  helpers do
    def find(id)
      Bag.find(id)
    end
  end

  show do
    next resource, include: ['bag-cards']
  end

  index do
    Bag.all
  end

  create(roles: :owner) do |attr|
    bag = Bag.new(attr.transform_keys(&:to_s))
    Database.save("bag", bag)
    next bag.id, bag
  end
end

resource :bag_cards, pkre: /[\da-f-]+/ do
  helpers do
    def find(id)
      BagCard.find(id)
    end
  end

  show

  index do
    BagCard.all
  end

  create(roles: :owner) do |attr|
    bag_card = BagCard.new(attr.transform_keys(&:to_s))
    Database.save("bag-card", bag_card)
    next bag_card.id, bag_card
  end

  update(roles: :owner) do |attr|
    bag_card = resource.update(attr)
    Database.save("bag-card", bag_card)
    next bag_card
  end

  destroy(roles: :owner) do
    Database.delete("bag-card", resource)
  end

  has_one :bag do
    pluck do
      resource.bag
    end

    graft(roles: :owner, sideload_on: [:create, :update]) do |rio|
      resource.bag_id = Bag.find(rio[:id]).id
      Database.save("bag-card", resource)
      true
    end
  end
end

before do
  headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS'
  headers['Access-Control-Allow-Origin'] = '*'
  headers['Access-Control-Allow-Headers'] = 'Accept, Authorization, Origin, Content-Type'
end

options '*' do
  response.headers['Allow'] = 'HEAD, GET, PUT, DELETE, OPTIONS, POST'
  response.headers['Access-Control-Allow-Headers'] = 'X-Requested-With, X-HTTP-Method-Override, Content-Type, Cache-Control, Accept, Authorization'
end

freeze_jsonapi
