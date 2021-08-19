require "csv"
require "google/apis/civicinfo_v2"
require "erb"

def legislators_by_zip(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = "AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw"

  begin
    legislators = civic_info.representative_info_by_address(
      address: zip,
      levels: "country",
      roles: ["legislatorUpperBody", "legislatorLowerBody"],
    )
    legislators.officials
  rescue
    "You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials"
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir("output") unless Dir.exist?("output")
  filename = "output/thanks_#{id}.html"
  File.open(filename, "w") do |file|
    file.puts(form_letter)
  end
end

def personal_letter(name, legislators)
  letter = File.read("form_letter.html")
  template = ERB.new(letter)
  template.result(binding)
end

puts "EventManager Initialized!"

def digit?(char)
  char.is_a?(String) && char.length == 1 && char >= "0" && char <= "9"
end

def clean_zipcode(zip)
  zip = "00000" unless zip
  zip = zip[0...5] if zip.length > 5
  zeroes_to_add = 5 - zip.length
  zip = ("0" * zeroes_to_add) + zip
end

def clean_phone_number(phone_num_str)
  phone = ""
  phone_num_str.each_char do |char|
    phone << char if digit?(char)
  end
  if phone.length == 10
    phone
  elsif phone.length == 11 && phone[0] == "1"
    phone[1..10]
  else
    "Invalid Phone Number"
  end
end

contents = CSV.open(
  "event_attendees.csv",
  headers: true,
  header_converters: :symbol,
)

reg_hours = Hash.new(0)
reg_days = Hash.new(0)

#returns best hour for registration
def peak_reg_hour(reg_hours)
  peak_reg_hours(reg_hours, 1)
end

#returns n best hours for registration
def peak_reg_hours(reg_hours, n)
  reg_hours = reg_hours.to_a
  reg_hours.sort_by! { |entry| entry[1] }

  if n >= reg_hours.length
    reg_hours.reverse.map { |entry| entry[0] }
  else
    reg_hours.last(n).reverse.map { |entry| entry[0] }
  end
end

def best_reg_day(reg_days)
  best_reg_days(reg_days, 1)
end

def best_reg_days(reg_days, n)
  reg_days = reg_days.to_a
  reg_days.sort_by! { |entry| entry[1] }

  if n >= reg_days.length
    reg_days.reverse.map { |entry| entry[0] }
  else
    reg_days.last(n).reverse.map { |entry| entry[0] }
  end
end

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zip = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zip(zip)
  letter = personal_letter(name, legislators)
  phone_number = clean_phone_number(row[:homephone])

  reg_date = row[:regdate]
  date_time = DateTime.strptime(reg_date, "%m/%d/%y %H:%M")
  reg_hours[date_time.hour.to_s] += 1
  reg_days[Date::DAYNAMES[date_time.wday]] += 1
  #save_thank_you_letter(id, letter)

end

num_for_peak = 3

puts "Best Hour: #{peak_reg_hour(reg_hours)[0]}:00"

peak_hours = peak_reg_hours(reg_hours, num_for_peak).map do |hour| 
  "#{hour}:00: #{reg_hours[hour.to_s]}" 
end
puts "Best #{num_for_peak} Hours: " + peak_hours.join(", ")

puts "Best Day: " + best_reg_day(reg_days)[0]

best_days = best_reg_days(reg_days, num_for_peak).map do |day| 
  "#{day}: #{reg_days[day]}"
end
puts "Best #{num_for_peak} Days: " + best_days.join(", ")
