class Craft
  attr_accessor :text, :prices

  def initialize(text)
    self.text = text
  end

  def cheapest_price(minimum_vouches: 0)
    applicable_prices = prices.select { |p| p["vouche_count"] >= minimum_vouches }

    return "" if applicable_prices.empty?
    cheapest_price = applicable_prices.first

    currency = case cheapest_price["price_coin"]
    when "CHAOS" then "c"
    when "EXALT" then "ex"
    else raise "unknown currency #{cheapest_price["price_coin"]}"
    end

    "#{cheapest_price["price"]}#{currency}"
  end

  def to_formatted_prices(minimum_vouches: 0)
    applicable_prices = prices.select { |p| p["vouche_count"] >= minimum_vouches }

    return "(no data)" if applicable_prices.empty?

    applicable_prices.map do |v|
      "#{v["price"]} #{v["price_coin"]} - lvl: #{v["seed_lvl"]} vch: #{v["vouche_count"]}"
    end.join("\n")
  end

  def fetch_prices
    response = HTTP
      .headers("x-api-key" => HorticraftingPricing::FORBIDDEN_HARVEST_API_KEY)
      .post(HorticraftingPricing::FORBIDDEN_HARVEST_SEARCH_ENDPOINT, json: { "searchText" => text })

    self.prices = JSON.parse(response.to_s)["results"].first(HorticraftingPricing::NUM_RESULTS_PER_CRAFT)
  end

  class << self
    def crafts
      @crafts ||= {}
    end

    def from_text(text)
      crafts[text] ||= new(text)
    end

    def fetch_pricing
      # raise crafts.inspect
      bar = TTY::ProgressBar.new("Fetching craft pricing [:bar] (:current / :total)", total: crafts.size, clear: true)
      pool = Thread.pool(10)
      semaphore = Mutex.new

      crafts.each_value do |craft|
        pool.process do
          craft.fetch_prices
          semaphore.synchronize { bar.advance(1) }
        end
      end

      pool.shutdown
    end
  end
end
