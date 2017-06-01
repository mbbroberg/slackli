require 'optparse'
require 'slack-ruby-client'
require 'pry'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: slackli.rb [options]"

  opts.on("-l", "--list") do |l|
    @list = true
  end
end.parse!

class Slackli
  attr_reader :channels
  
  def initilize(token)
    Slack.configure do |config|
      config.token = token
      fatal "No Slack token provided. You're missing a value for $SLACK_ADMIN_TOKEN." unless config.token
    end
    @client ||= Slack::Web::Client.new
    @channels = Set.new(get_unarchived_channels.collect{|c| Channel.new(c, @client)})
  end
  
  # get channels when provided an authenticated client
  def get_unarchived_channels
    channels = @client.channels_list.channels
    channels.reject(&:is_archived?)
  end
end

slackli = Slackli.new(ENV['SLACK_ADMIN_TOKEN'])
binding.pry