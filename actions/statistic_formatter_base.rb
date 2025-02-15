class StatisticFormatterBase
    attr_reader :data

    # SQL query to execute
    SQL = 'SELECT 1'.freeze

    # @param sql_client [Mysql2::Client] client to execute the SQL query
    # @param block [Proc] optional block to filter the data
    #
    # @example
    #   StatisticFormatterBase.new(client) { |row| row['name'] == 'John' }
    #
    # @return [void]
    def initialize(sql_client, &block)
        @data = sql_client.query(self.class::SQL)
                          .select { |row| block ? block.call(row) : true }
                          .map { |row| format(row) }
    end
    
    # Format the row
    #
    # @param row [Hash] row to format
    # @return [String] formatted row
    def format(row)
        row.to_s
    end
end