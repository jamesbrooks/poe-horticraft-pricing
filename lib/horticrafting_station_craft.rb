require 'forwardable'

class HorticraftingStationCraft
  extend Forwardable

  attr_accessor :craft, :ilevel

  def_delegators :@craft, :cheapest_price

  def initialize(raw_text)
    text, ilevel = raw_text.scan(/(.*)\((\d+)\)\z/)[0]
    text = text.gsub(/(<white>|{|})/, "").strip

    @craft = Craft.from_text(text)
    @ilevel = ilevel.to_i
  end
end
