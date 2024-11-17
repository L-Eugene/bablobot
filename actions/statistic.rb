require 'telegram/bot'

class ActionStatistic < Action
    def run
        currency_data = @client.query(<<~SQL).map { |row| "<b>#{row['mnemonic']}:</b> #{row['total'].to_f.round(2)}" }
            SELECT
                c.mnemonic,
                sum(s.quantity_num/s.quantity_denom) as total
            FROM
                splits s
                LEFT JOIN accounts a ON s.account_guid = a.guid
                LEFT JOIN commodities c ON a.commodity_guid = c.guid
            WHERE a.account_type IN ('ASSET', 'CASH', 'STOCK')
            GROUP BY a.commodity_guid
            HAVING total > 0
        SQL

        accounts_to_track = @config[:watchlist] || []

        savings_summary = @client.query(<<~SQL)
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
            "<b>#{row['name']}:</b> #{row['total_today']} [Δ₃₀ = #{delta}] "
        end

        html = <<~HTML
            #{currency_data.compact.join("\n")}
        
            #{savings_summary.join("\n")}
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
