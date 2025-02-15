require_relative 'statistic_formatter_base'

class StatisticFormatterCurrency < StatisticFormatterBase
    SQL = <<~SQL
        SELECT
            c.mnemonic,
            sum(s.quantity_num/s.quantity_denom) as total
        FROM
            splits s
            LEFT JOIN accounts a ON s.account_guid = a.guid
            LEFT JOIN commodities c ON a.commodity_guid = c.guid
        WHERE a.account_type IN ('ASSET', 'CASH')
        GROUP BY a.commodity_guid
        HAVING total > 0
    SQL

    def format(row)
        "<b>#{row['mnemonic']}:</b> #{row['total'].to_f.round(2)}"
    end
end