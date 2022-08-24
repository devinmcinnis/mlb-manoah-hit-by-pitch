require 'pry-byebug'
require 'active_support/core_ext/numeric/time'
require 'httparty'
require 'json'

class Array
  def to_table
    column_sizes = self.reduce([]) do |lengths, row|
      row.each_with_index.map{|iterand, index| [lengths[index] || 0, iterand.to_s.length].max}
    end
    puts head = '-' * (column_sizes.inject(&:+) + (3 * column_sizes.count) + 1)
    self.each do |row|
      row = row.fill(nil, row.size..(column_sizes.size - 1))
      row = row.each_with_index.map{|v, i| v = v.to_s + ' ' * (column_sizes[i] - v.to_s.length)}
      puts '| ' + row.join(' | ') + ' |'
    end
    puts head
  end
end

stats_url = 'https://bdfed.stitch.mlbinfra.com/bdfed/stats/player?stitch_env=prod&season=2021&sportId=1&stats=season&group=pitching&gameType=R&limit=100&offset=0&sortStat=hitBatsman&order=desc'
file_name = 'db.json'
f = File.new(file_name)

if f.atime < 1.hour.ago
  puts 'Fetching latest stats...'
  response = HTTParty.get(stats_url)
  File.write(file_name, response)
end

data = JSON.parse(File.read(file_name))
arr = []

data['stats'].each do |pitcher|
  hb_percentage = (pitcher['hitBatsmen'].to_f / pitcher['battersFaced'] * 1000).floor / 10.0
  bf_hb_avg = (pitcher['battersFaced'].to_f / pitcher['hitBatsmen'] * 10).floor / 10.0
  ip_hb_avg = (pitcher['inningsPitched'].to_f / pitcher['hitBatsmen'] * 10).floor / 10.0
  # binding.pry
  arr.push [
    "#{pitcher['teamAbbrev']} #{pitcher['playerFullName']} #{pitcher['qualityStarts'] > 0 ? '(SP)' : ''}",
    pitcher['hitBatsmen'],
    pitcher['battersFaced'],
    "#{hb_percentage}%",
    "#{bf_hb_avg}",
    pitcher['inningsPitched'],
    "#{ip_hb_avg}"
  ]
end

# Only pitchers with over 400 innings pitched
arr.select! do |p|
  p[2].to_i > 400
end

output = [
  ['Pitcher name', 'Batters hit', 'Batters faced', '% of batters faced', 'Batters faced per hit', 'Innings pitched', 'Innings per hit batter'],
  ['------------', '-----------', '-------------', '------------------', '---------------------', '---------------', '----------------------']
]

column = 3

# Sort by hit-batters percentage
output += arr.sort do |a, b|
  column === 3 ? a[column].to_i > b[column].to_i ? -1 : 1 : a[column].to_i < b[column].to_i ? -1 : 1
end

puts output.to_table