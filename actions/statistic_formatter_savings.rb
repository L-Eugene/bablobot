require_relative 'statistic_formatter_base'

class StatisticFormatterSavings < StatisticFormatterBase
    SQL = <<~SQL
        SELECT
            a.name,
            sum(s.quantity_num/s.quantity_denom) as total_today,
            sum(IF(t.post_date < DATE_SUB(CURDATE(), INTERVAL 30 DAY), s.quantity_num/s.quantity_denom, 0)) as total_30_days_ago
        FROM
            splits s
            LEFT JOIN accounts a ON s.account_guid = a.guid
            LEFT JOIN transactions t ON s.tx_guid = t.guid
        GROUP BY a.name
    SQL

    def format(row)
        row['total_30_days_ago'] = row['total_30_days_ago'].to_f.round(2)
        row['total_today'] = row['total_today'].to_f.round(2)
        delta = row['total_today'] - row['total_30_days_ago']
        "<b>#{row['name']}:</b> #{row['total_today']} [Δ₃₀ = #{'+' if delta.positive?}#{delta.round(2)}] "
    end
end