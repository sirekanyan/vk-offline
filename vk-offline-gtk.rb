#!/usr/bin/env ruby
Dir.chdir File.expand_path File.dirname($0)
require_relative 'lib/helper'
require_relative 'lib/widget'
require_relative 'lib/vk-offline'

application = VkontakteOffline.new

application.load_friends(fields: 'uid', order: 'hints')

if File.exists?('friends.txt')
  File.read('friends.txt').split("\n").each_slice(250) do |i|
    application.load_users(user_ids: i.join(','))
  end
else
  puts '| You may specify more users with friends.txt file'
  puts '| Just create friends.txt file with list of user ids'
end

VkontakteWidget.new(application).start