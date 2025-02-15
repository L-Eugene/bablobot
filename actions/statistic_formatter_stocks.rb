require_relative 'statistic_formatter_base'

class StatisticFormatterStocks < StatisticFormatterBase
    SQL = <<~SQL
            WITH 
                NumberedPrices AS (
                    SELECT
                        ROW_NUMBER() OVER (PARTITION BY commodity_guid ORDER BY date desc) as order_id,
                        commodity_guid,
                        currency_guid,
                        date,
                        value_num,
                        value_denom
                    FROM
                        prices
                ),
                LatestPrices AS (
                    SELECT * FROM NumberedPrices WHERE order_id = 1
                ),
                ConversionRates AS (
                    SELECT
                        date,
                        c.mnemonic AS `from`,
                        c2.mnemonic AS `to`,
                        value_num / value_denom AS rate
                    FROM 
                        LatestPrices lp
                        LEFT JOIN commodities c ON lp.commodity_guid = c.guid
                        LEFT JOIN commodities c2 ON lp.currency_guid = c2.guid
                ),
                PreCalculated AS (
                    SELECT
                        c.fullname AS fullname,
                        c.mnemonic AS mnemonic,
                        sum(s.quantity_num/s.quantity_denom) as total,
                        p.`date` as date,
                        p.value_num / p.value_denom as rate,
                        c2.mnemonic AS currency,
                        IF (c2.mnemonic = 'BGN', 1, cr.rate) AS leva_rate
                    FROM
                        splits s
                        LEFT JOIN accounts a ON s.account_guid = a.guid
                        LEFT JOIN LatestPrices p ON a.commodity_guid = p.commodity_guid
                        LEFT JOIN commodities c ON a.commodity_guid = c.guid
                        LEFT JOIN commodities c2 ON p.currency_guid = c2.guid
                        LEFT JOIN ConversionRates cr ON c2.mnemonic = cr.`from` AND 'BGN' = cr.`to`
                    WHERE a.account_type IN ('STOCK', 'MUTUAL')
                    GROUP BY a.commodity_guid
                    HAVING total > 0
                )
            SELECT
                fullname,
                mnemonic,
                total,
                date,
                total * rate * leva_rate AS leva
            FROM PreCalculated
    SQL

    def format(row)
        "<b>#{row['mnemonic']} (#{row['fullname']}):</b> #{row['total'].to_f.round(2)} (≈ #{row['leva'].to_f.round(2)} BGN)"
    end
end