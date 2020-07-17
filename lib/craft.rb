class Craft
  attr_accessor :text, :prices

  def initialize(text)
    # Replace numbers with generic hashes (#)
    self.text = text.gsub(/\d+/, "#").delete("'")
  end

  def cheapest_price(minimum_vouches: 0)
    applicable_prices = prices.select { |p| p["vouche_count"] >= minimum_vouches }
    applicable_prices = applicable_prices.first(HorticraftingPricing::NUM_RESULTS_PER_CRAFT)

    return "-" if applicable_prices.empty?

    cheapest_price = applicable_prices.first

    currency = case cheapest_price["price_coin"]
    when "ALCH" then "alch"
    when "CHAOS" then "c"
    when "EX" then "ex"
    when "MIRROR" then "mir"
    else cheapest_price["price_coin"].downcase
    end

    "#{cheapest_price["price"]}#{currency}"
  end

  def to_formatted_prices(minimum_vouches: 0)
    applicable_prices = prices.select { |p| p["vouche_count"] >= minimum_vouches }
    applicable_prices = applicable_prices.first(HorticraftingPricing::NUM_RESULTS_PER_CRAFT)

    return "(no data)" if applicable_prices.empty?

    applicable_prices.map do |v|
      "#{v["price"]} #{v["price_coin"]} - lvl: #{v["seed_lvl"]} vch: #{v["vouche_count"]}"
    end.join("\n")
  end

  def fetch_prices(conn)
    response = conn
      .headers("x-api-key" => HorticraftingPricing::FORBIDDEN_HARVEST_API_KEY)
      .post("/search", json: { "searchText" => text })

    self.prices = JSON.parse(response.to_s)["results"]
  end

  class << self
    def crafts
      @crafts ||= {}
    end

    def from_text(text)
      crafts[text] ||= new(text)
    end

    def fetch_pricing
      bar = TTY::ProgressBar.new("Fetching craft pricing [:bar] (:current / :total)", total: crafts.size, clear: true)
      pool = ConnectionPool.new(size: HorticraftingPricing::HTTP_WORKER_POOL_SIZE, timeout: 60) { HTTP.persistent("https://api.forbiddenharvest.com") }
      semaphore = Mutex.new

      crafts.each_value.map do |craft|
        Thread.new do
          pool.with { |conn| craft.fetch_prices(conn) }
          semaphore.synchronize { bar.advance(1) }
        end
      end.each(&:join)
    end
  end
end
