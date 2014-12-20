#!/usr/bin/env ruby
require 'gtk2'
Dir.chdir File.expand_path File.dirname($0)
require 'vk-ruby'
require_relative 'lib/helper.rb'
require_relative 'lib/widget.rb'

$vk = Vkontakte.new

def add_to_list(friends)
  online = friends.select { |u| u['online'] == 1 }.count
  friends.each do |u|
    key = u['uid']
    first = u['first_name'] + ' ' + u['last_name']
    last = u['last_name'] + ' ' + u['first_name']
    if $users.has_key? key
      $users[key] += [first, last]
    else
      $users[key] = [first, last]
    end
  end
  $online += online
  puts "#{friends.count} friends added, online: #{online}"
end

$users = {}
$online = 0

add_to_list($vk.friends_get(fields: 'uid,online', order: 'hints'))
add_to_list($vk.friends_get(fields: 'uid,online', order: 'hints', lang: 'ru'))

if File.exists?('friends.txt')
  uids = File.read('friends.txt').split("\n")
  uids.each_slice(250) do |i|
    add_to_list($vk.users_get(user_ids: i.join(','), fields: 'online'))
    add_to_list($vk.users_get(user_ids: i.join(','), fields: 'online', lang: 'ru'))
  end
else
  puts '| You may specify more users with friends.txt file'
  puts '| Just create friends.txt file with list of user ids'
end

def parse_uid(username)
  if u = username.match(/<id(\d+)>$/)
    u[1]
  elsif u = username.match(/^(\d+)/)
    u[1]
  else
    nil
  end
end

def refresh_history(uid)
  buff = ''
  username = ''
  online = false
  if uid
    user = $vk.users_get(:user_id => uid, :fields => 'online').first
    if user == -1
      buff = [-1]
    else
      username = user['first_name']
      online = user['online'] == 1
      buff = $vk.messages_getHistory(:user_id => uid)
    end
  end
  ans = buff.shift
  buff_temp = ''
  buff.each do |msg|
    buff_temp += VkHelper.message(msg, username, online: online) + "\n"
  end
  buff_temp = '(no messages yet)' if buff.empty?
  buff_temp = '(check user id)' if ans == -1
  buff_temp
end

def refresh_new_msgs(uid)
  buff = $vk.messages_get
  ans = buff.shift
  buff_temp = ''
  buff.each do |msg|
    buff_temp += VkHelper.message(msg, msg['uid']) + "\n"
  end
  buff_temp = '(no messages yet)' if buff.empty?
  buff_temp = '(check user id)' if ans == -1
  buff_temp
end

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
