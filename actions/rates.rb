require 'alphavantagerb'
require 'securerandom'

class ActionRates < Action
    def run
        return if @config[:stocks].public_send(:[], :stocks).nil?

        client = Alphavantage::Client.new(key: @config[:stocks][:alphavantage_token])

        @config[:stocks][:stocks].each do |stock_record|
            # Get stock price and exchange rate
            stock = client.stock(symbol: stock_record[:symbol]).quote
            rate = if stock_record[:currency] == 'USD'
                       1
                   else
                       client.exchange(to: stock_record[:currency], from: 'USD').now.exchange_rate.to_f
                   end

            # Check if the stock price is already in the database
            query = <<~SQL
                SELECT p.*
                FROM
                    prices p
                    LEFT JOIN commodities c ON p.commodity_guid = c.guid
                    LEFT JOIN commodities c2 ON p.currency_guid = c2.guid
                WHERE
                    c.mnemonic = '#{stock_record[:symbol]}'
                    AND c2.mnemonic = '#{stock_record[:currency]}'
                    AND DATEDIFF(p.`date`, '#{stock.latest_trading_day}') = 0
            SQL

            # If the stock price is not in the database, insert it
            if @client.query(query).count.zero?
                @client.query(<<~SQL)
                    INSERT INTO prices
                    SET
                        guid = '#{SecureRandom.uuid.gsub('-', '')}',
                        commodity_guid = (SELECT guid FROM commodities WHERE mnemonic = '#{stock_record[:symbol]}' LIMIT 1),
                        currency_guid = (SELECT guid FROM commodities WHERE mnemonic = '#{stock_record[:currency]}' LIMIT 1),
                        date = '#{stock.latest_trading_day}',
                        source = 'user:price-editor',
                        type = 'last',
                        value_num = #{(stock.price.to_f * 100 * rate).to_i},
                        value_denom = 100
                SQL
            end
        end
    end
end