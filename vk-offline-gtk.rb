#!/usr/bin/env ruby
require 'gtk2'
Dir.chdir File.expand_path File.dirname($0)
require_relative 'lib/helper'
require_relative 'lib/widget'
require_relative 'lib/vk-offline'

app = VkontakteOffline.new

app.load_friends(fields: 'uid,online', order: 'hints')

if File.exists?('friends.txt')
  File.read('friends.txt').split("\n").each_slice(250) do |i|
    app.load_users(user_ids: i.join(','), fields: 'online')
  end
else
  puts '| You may specify more users with friends.txt file'
  puts '| Just create friends.txt file with list of user ids'
end

$vk = app.vk
$users = app.users

Gtk::Window.create do |win|
  win.set_title 'Offline Messenger'
  win.set_size_request(420, 500)
  win.border_width = 10
  win.signal_connect('delete_event') { Gtk.main_quit }
  win.add(mainbox)
  win.show_all
end

require_relative 'lib/icon'

Gtk.main
