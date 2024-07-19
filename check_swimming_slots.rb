require 'net/http'
require 'json'
require 'time'
require 'telegram/bot'

# Fetch the JSON data from the URL with headers
def fetch_json(url)
  uri = URI(url)
  request = Net::HTTP::Get.new(uri)
  request['Accept'] = 'application/json'
  request['Origin'] = 'https://bookings.better.org.uk'

  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
    http.request(request)
  end

  JSON.parse(response.body)
end

class Slot
  attr_reader :data

  def initialize(data)
    @data = data
  end

  def bookable?
    data['action_to_show']['status'] == 'BOOK'
  end

  def slot_start_time
    Time.parse("#{data['date']['raw']} #{data['starts_at']['format_24_hour']}")
  end

  def in_range?(range_start, range_end)
    range = Time.parse(range_start)..Time.parse(range_end)
    range.cover?(slot_start_time)
  end

  def name; data['name']; end
  def start_time; data['starts_at']['format_12_hour']; end
  def end_time; data['ends_at']['format_12_hour']; end
  def location; data['location_name']; end
  def spaces_remaining; data['spaces_remaining']; end
end

# Parse the JSON data and identify bookable slots within the given time range
def find_bookable_slots(data, start_time, end_time)
  data['data']
    .map {|d| Slot.new(d)}
    .select(&:bookable?)
    .select {|s| s.in_range?(start_time, end_time) }
end

# Send a message via Telegram
def send_telegram_message(token, chat_id, message)
  Telegram::Bot::Client.run(token) do |bot|
    bot.api.send_message(chat_id: chat_id, text: message)
  end
end

require 'date'
require 'time'
day = Date.parse("2024-07-20")

# URL of the JSON file
url = "https://better-admin.org.uk/api/activities/venue/london-fields-lido/activity/swimmingft/times?date=#{day.to_s}"

# Fetch and parse JSON data
data = fetch_json(url)

start_time = "08:00"
end_time = "14:00"

# Find bookable slots within the specified time range
bookable_slots = find_bookable_slots(data, start_time, end_time)

# Prepare and send the Telegram message if there are bookable slots
if bookable_slots.any?
  puts "#{bookable_slots.size} slots available on #{day.to_s} between #{start_time} and #{end_time}"

  message = "Bookable swimming slots between #{start_time} and #{end_time}:\n"
  bookable_slots.each do |slot|
    message += "#{slot.name} from #{slot.start_time} to #{slot.end_time} at #{slot.location}, Spaces remaining: #{slot.spaces_remaining}\n"
  end

  # Send the message via Telegram
  bot_token = ENV['BOT_TOKEN']
  chat_id = ENV['CHAT_ID']
  send_telegram_message(bot_token, chat_id, message)
else
  puts "No slots available on #{day.to_s} between #{start_time} and #{end_time}"
end
