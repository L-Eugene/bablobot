require 'mysql2'
require 'date'
require 'yaml'

class Action
    def initialize(options)
        @options = options

        @config = YAML.load_file(
            File.join(__dir__, '..', 'config.yml'),
            symbolize_names: true
        )

        @client = Mysql2::Client.new(@config[:database])
    end
end