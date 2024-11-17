require 'optparse'

Dir[File.join(__dir__, 'actions', '*.rb')].each { |file| require file }

options = {
    output: :stdout,
    action: :statistic
}
OptionParser.new do |opts|
    opts.banner = "Usage: app.rb [options]"

    opts.on("--action ACTION", [:statistic, :rates], "Select action (statistic, rates_refresh)") do |a|
        options[:action] = a
    end

    opts.on("--output OUTPUT", [:chat, :stdout], "Select output (chat, stdout)") do |o|
        options[:output] = o
    end
end.parse!

action = Object.const_get("Action#{options[:action].to_s.capitalize}").new(options)
action.run