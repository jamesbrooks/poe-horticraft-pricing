class HorticraftingStation
  attr_accessor :x, :y, :crafts

  def initialize(opts = {})
    self.x, self.y = opts.values_at("x", "y")
    self.crafts = opts["craftedMods"].map { |craft| HorticraftingStationCraft.new(craft) }
  end

  def suggested_pricing_note(minimum_vouches: nil)
    "#" + [ crafts.map { |c| c.cheapest_price(minimum_vouches: minimum_vouches) }, nil, nil, nil ].flatten.first(3).join("/")
  end
end
