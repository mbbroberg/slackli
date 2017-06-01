require 'optparse'
require 'slack-ruby-client'
require 'hashie'
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
  
  def initialize(token)
    Slack.configure do |config|
      config.token = ENV['SLACK_ADMIN_TOKEN']
      fatal "No Slack token provided. You're missing a value for $SLACK_ADMIN_TOKEN." unless config.token
    end
    @@client ||= Slack::Web::Client.new
    @channels = Set.new(get_unarchived_channels.collect{|c| Channel.new(c, @@client)})
  end
  
  # get channels when provided an authenticated client
  def get_unarchived_channels
    channels = @@client.channels_list.channels
    channels.reject(&:is_archived?)
  end
  
  def list_channels
    name = "Channel"
    members = "Members"
    created = "Created"
    used = "Last Used"
    
    printf "%-20s %-15s %-15s %-15s\n", name, members, created, used 
    @channels.each {|c| c.list}    
  end
end

class Channel < Hashie::Mash
  @@client

  def initialize(args, client={})
    Hashie.logger = Logger.new(nil) # see issue here: https://github.com/omniauth/omniauth/issues/872#issuecomment-276501012
    args.each_pair do |k, v|
      self[k] = v
    end
    @now = Time.now
    @@client ||= client
  end
  
  ##### A ton of helper methods below #####
  
  def list
    name = self.name
    members = self.number_of_members
    created = self.days_since_created
    used = self.days_since_used
    
    printf "%-20s %-15d %-15.1f %-15.1f\n", name, members, created, used
  end
  
  def number_of_members
    self.members.size
  end

  def last_post_time
    # checking on last comment date time.
    # grabbing the last 100 messages - max available for this API call.
    msgs = @@client.channels_history(channel: self.id).messages
    human_msgs = msgs.reject(&:bot_id?)
    if human_msgs.empty?
      last_post_time = Time.at(0)
    else
      unix = human_msgs[0].ts.split('.')[0].to_i unless human_msgs.empty?
      last_post_time = Time.at(unix)
    end
  end

  def create_time
    Time.at(created.to_i)
  end

  def days_since_created
    ((@now - create_time) / (60 * 60 * 24))
  end

  def days_since_used
    ((@now - last_post_time) / (60 * 60 * 24))
  end

  # Default to seeing if made in the last week
  def younger? (days = 7)
    days_since_created < days.to_i
  end

  # Default to seeing if used in the last week
  def used_since? (days = 7)
    days_since_used > days
  end

end

slackli = Slackli.new(ENV['SLACK_ADMIN_TOKEN'])
if @list 
  slackli.list_channels
end