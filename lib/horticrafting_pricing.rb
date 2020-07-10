require 'thread/pool'

class HorticraftingPricing
  LEAGUE = "Harvest".freeze
  STASH_TABS_ENDPOINT = "https://www.pathofexile.com/character-window/get-stash-items?league=%s&tabs=1&accountName=%s".freeze
  STASH_TAB_CONTENTS_ENDPOINT = "https://www.pathofexile.com/character-window/get-stash-items?league=%s&tabs=0&tabIndex=%s&accountName=%s".freeze
  FORBIDDEN_HARVEST_SEARCH_ENDPOINT = "https://api.forbiddenharvest.com/search".freeze
  FORBIDDEN_HARVEST_API_KEY = "LUzWaKHO0i3ezyOgKocS63ZCh8bxAp3e8bzIteJP".freeze
  NUM_RESULTS_PER_CRAFT = 3

  attr_accessor :spinner, :minimum_vouches, :poesessid, :account_name, :tab_id, :horticrafting_stations

  def run
    self.minimum_vouches = ask("Minimum Vouches Required (for determining price suggestions)", :minimum_vouches, 5).to_i
    self.poesessid = ask("POESESSID", :poesessid)
    self.account_name = ask("Account Name", :account_name)
    self.tab_id = select("What tab are your Horticrafting Stations in?", fetch_tab_list, :tab_id)
    self.horticrafting_stations = fetch_horticrafting_stations_in_tab(tab_id)

    Craft.fetch_pricing

    display_suggested_station_pricing
    display_pricing_report

    config.write(force: true)
  end

  def display_suggested_station_pricing
    priced_stations = horticrafting_stations.each.with_object([]) do |station, matrix|
      (matrix[station.y] ||= [])[station.x] = station.suggested_pricing_note(minimum_vouches: minimum_vouches)
    end

    priced_stations.each do |stations|
      puts "  " + stations.compact.map { |s| s.ljust(15) }.join
    end

    puts "\n\n"
  end

  def display_pricing_report
    table = TTY::Table.new

    Craft.crafts.each_value do |craft|
      table << [ craft.text, craft.to_formatted_prices(minimum_vouches: minimum_vouches) ]
    end

    puts table.render :ascii, multiline: true, padding: [ 0, 1 ], border: { separator: :each_row }
  end

private
  def ask(question, config_key = nil, default = nil)
    TTY::Prompt.new.ask("#{question}:", default: (config_key ? config.fetch(config_key) : default)).tap do |response|
      config.set(config_key, value: response) if config_key
    end
  end

  def select(question, choices, config_key)
    TTY::Prompt.new.select(question, choices, default: (config.fetch(config_key).to_i + 1 if config_key), per_page: 1_000).tap do |response|
      config.set(config_key, value: response) if config_key
    end
  end

  def fetch_tab_list
    start_spinner("Fetching Stash Tabs")
    response = HTTP.headers(cookie: "POESESSID=#{poesessid}").get(format(STASH_TABS_ENDPOINT, LEAGUE, account_name))

    unless response.status.success?
      stop_spinner("(error fetching tabs, check POESESSID and Account Name)")
      exit(1)
    end

    stop_spinner("(done)")

    # name => id lookup hash
    JSON.parse(response.to_s)["tabs"].each.with_object({}) { |t, h| h["#{t["i"]}: #{t["n"]}"] = t["i"] }
  end

  def fetch_horticrafting_stations_in_tab(tab_id)
    start_spinner("Fetching Tab Contents")
    response = HTTP.headers(cookie: "POESESSID=#{poesessid}").get(format(STASH_TAB_CONTENTS_ENDPOINT, LEAGUE, tab_id, account_name))

    unless response.status.success?
      stop_spinner("(error fetching tab contents)")
      exit(1)
    end

    stop_spinner("(done)")

    payload = JSON.parse(response.to_s)
    horticrafting_stations = payload["items"].select { |item| item["typeLine"] == "Horticrafting Station" && item["craftedMods"] }

    horticrafting_stations.map { |data| HorticraftingStation.new(data) }
  end

  def start_spinner(message)
    puts "\n"
    self.spinner = TTY::Spinner.new(":spinner #{message}", format: :dots_2)
    spinner.auto_spin
  end

  def stop_spinner(result = "(done)")
    spinner.stop(result)
    self.spinner = nil
    puts "\n"
  end

  def config
    @config ||= begin
      TTY::Config.new.tap do |config|
        config.append_path Dir.pwd
        config.read if config.exist?
      end
    end
  end
end
