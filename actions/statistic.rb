require 'telegram/bot'
require_relative 'statistic_formatter_currency'
require_relative 'statistic_formatter_stocks'
require_relative 'statistic_formatter_savings'

class ActionStatistic < Action
    def run
        currency_data = StatisticFormatterCurrency.new(@client)
        
        stocks_data = StatisticFormatterStocks.new(@client)

        accounts_to_track = @config[:watchlist] || []

        savings_summary = StatisticFormatterSavings.new(@client) do |row|
            accounts_to_track.include?(row['name'])
        end
        
        @client.query(<<~SQL)
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

        html = <<~HTML
            #{currency_data.data.join("\n")}
        
            #{stocks_data.data.join("\n")}

            #{savings_summary.data.join("\n")}
        HTML

        case @options[:output]
        when :stdout
            puts html
        when :chat
            Telegram::Bot::Client.run(@config[:telegram][:token]) do |bot|
                bot.api.send_message(chat_id: @config[:telegram][:chat_id], text: html, parse_mode: 'HTML')
            end
        end
    end
end
