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

# Parse the JSON data and identify bookable slots within the given time range
def find_bookable_slots(data, start_time_str, end_time_str)
  start_time = Time.parse(start_time_str)
  end_time = Time.parse(end_time_str)
  
  bookable_slots = []

  data['data'].each do |slot|
    slot_start_time = Time.parse("#{slot['date']['raw']} #{slot['starts_at']['format_24_hour']}")
    slot_end_time = Time.parse("#{slot['date']['raw']} #{slot['ends_at']['format_24_hour']}")

    if slot['action_to_show']['status'] == 'BOOK' && slot_start_time >= start_time && slot_end_time <= end_time
      bookable_slots << {
        name: slot['name'],
        start_time: slot['starts_at']['format_12_hour'],
        end_time: slot['ends_at']['format_12_hour'],
        location: slot['location_name'],
        spaces_remaining: slot['spaces_remaining']
      }
    end
  end

  bookable_slots
end

# Send a message via Telegram
def send_telegram_message(token, chat_id, message)
  Telegram::Bot::Client.run(token) do |bot|
    bot.api.send_message(chat_id: chat_id, text: message)
  end
end

# URL of the JSON file
url = 'https://better-admin.org.uk/api/activities/venue/london-fields-lido/activity/swimmingft/times?date=2024-07-20'

# Fetch and parse JSON data
data = fetch_json(url)

# Define the time range (example: from 6:00am to 8:00am)
require 'date'
require 'time'
tomorrow = Date.today+1

start_time = DateTime.new(tomorrow.year, tomorrow.month, tomorrow.day, 8, 0, 0)
end_time = DateTime.new(tomorrow.year, tomorrow.month, tomorrow.day, 14, 0, 0)

# Find bookable slots within the specified time range
bookable_slots = find_bookable_slots(data, start_time, end_time)

# Prepare and send the Telegram message if there are bookable slots
if bookable_slots.any?
  message = "Bookable swimming slots between #{start_time} and #{end_time} tomorrow:\n"
  bookable_slots.each do |slot|
    message += "#{slot[:name]} from #{slot[:start_time]} to #{slot[:end_time]} at #{slot[:location]}, Spaces remaining: #{slot[:spaces_remaining]}\n"
  end

  # Send the message via Telegram
  bot_token = ENV['BOT_TOKEN']
  chat_id = ENV['CHAT_ID']
  send_telegram_message(bot_token, chat_id, message)
end
