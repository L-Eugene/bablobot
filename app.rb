require 'mysql2'
require 'telegram/bot'
require 'date'
require 'yaml'

require 'optparse'

options = {
    output: :stdout
}
OptionParser.new do |opts|
    opts.banner = "Usage: app.rb [options]"

    opts.on("--output OUTPUT", [:chat, :stdout], "Select output (chat, stdout)") do |o|
        options[:output] = o
    end
end.parse!

# Create a new MySQL client
client = Mysql2::Client.new(
    YAML.load_file(
        File.join(__dir__, 'database.yml'),
        symbolize_names: true
    )
)

currency_data = client.query(<<~SQL).map { |row| "<b>#{row['fullname']}:</b> #{row['total'].to_f.round(2)}" unless row['total'].zero? }
    SELECT c.fullname, sum(s.quantity_num/s.quantity_denom) as total
    FROM
        splits s
        LEFT JOIN accounts a ON s.account_guid = a.guid
        LEFT JOIN commodities c ON a.commodity_guid = c.guid
    WHERE a.account_type IN ('ASSET', 'CASH', 'STOCK')
    GROUP BY a.commodity_guid
SQL

accounts_to_track = YAML.load_file(
    File.join(__dir__, '30days.yml'),
    symbolize_names: true
)[:accounts] || []

savings_summary = client.query(<<~SQL)
    SELECT
        a.name,
        sum(s.quantity_num/s.quantity_denom) as total_today,
        sum(IF(t.post_date < DATE_SUB(CURDATE(), INTERVAL 30 DAY), s.quantity_num/s.quantity_denom, 0)) as total_30_days_ago
    FROM
        splits s
        LEFT JOIN accounts a ON s.account_guid = a.guid
        LEFT JOIN transactions t ON s.tx_guid = t.guid
    WHERE a.name IN (#{accounts_to_track.map { |name| "'#{name}'" }.join(',')})
    GROUP BY a.name
SQL

savings_summary = savings_summary.map do |row|
    row['total_30_days_ago'] = row['total_30_days_ago'].to_f.round(2)
    row['total_today'] = row['total_today'].to_f.round(2)
    delta = (row['total_30_days_ago'].to_f < row['total_today'].to_f ? '+' : '') + (row['total_today'] - row['total_30_days_ago']).to_s
    "<b>#{row['name']}:</b> #{row['total_today']} (#{row['total_30_days_ago']}) [#{delta}] "
end

html = <<~HTML
    #{currency_data.compact.join("\n")}

    #{savings_summary.join("\n")}
HTML

# Close the database connection
client.close

case options[:output]
when :stdout
    puts html
when :chat
    config = YAML.load_file(
        File.join(__dir__, 'telegram.yml'),
        symbolize_names: true
    )
    
    Telegram::Bot::Client.run(config[:token]) do |bot|
        bot.api.send_message(chat_id: config[:chat_id], text: html, parse_mode: 'HTML')
    end
end
