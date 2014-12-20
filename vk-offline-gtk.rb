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

def user_completion
  users = Gtk::EntryCompletion.new
  model = Gtk::ListStore.new(String)
  $users.each do |k, names|
    iter = model.append
    iter[0] = "#{k} (#{names[0]})"
    names.each do |v|
      iter = model.append
      iter[0] = "#{v} <id#{k}>"
    end
  end
  users.model = model
  users.text_column = 0
  users
end

def send_button(text, user, msg, history)
  Gtk::Button.create(text) do |button|
    button.signal_connect('clicked') do
      uid = parse_uid(user.text)
      unless uid.nil?
        mid = $vk.messages_send(:user_id => uid, :message => msg.text)
        usr = $vk.user(uid)['first_name']
        puts "Message ##{mid} for #{usr} has been sent"
        history.buffer.text = "Me:\nsending...\n\n" + history.buffer.text
        Thread.new do
          history.buffer.text = refresh_history(uid)
        end
      end
    end
    return button
  end
end

def scrolled_win(textview)
  Gtk::ScrolledWindow.create do |scrolled_win|
    scrolled_win.add(textview)
    scrolled_win.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_ALWAYS)
    Gtk::VBox.create(false, 5) do |vbox|
      vbox.pack_start_defaults(scrolled_win)
    end
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

def history_textview(user)
  Gtk::TextView.create do |history|
    user.signal_connect('focus_out_event') {
      Thread.new {
        uid = parse_uid(user.text)
        history.buffer.text = refresh_history(uid) unless uid.nil?
        history.buffer.text = '(no messages)' if uid.nil?
      }
      false
    }
    history.left_margin = 10
    history.editable = false
    history.wrap_mode = Gtk::TextTag::WRAP_WORD
    return history
  end
end

def get_mainbox
  Gtk::VBox.create(false, 0) do |mainbox|
    user = Gtk::Entry.new
    msg = Gtk::Entry.new
    user.completion = user_completion
    mainbox.append(simple_box(:user, user))
    mainbox.append(simple_box(:message, msg))
    history = history_textview(user)
    mainbox.append(main_buttons(user, msg, history))
    mainbox.append(Gtk::HSeparator.new, fill: true)
    mainbox.append(scrolled_win(history), expand: true, fill: true)
  end
end

Gtk::Window.create do |win|
  win.set_title 'Offline Messenger'
  win.set_size_request(420, 500)
  win.border_width = 10
  win.signal_connect('delete_event') { Gtk.main_quit }
  win.add(get_mainbox)
  win.show_all
end

icon = Gtk::StatusIcon.new
icon.pixbuf = Gdk::Pixbuf.new('vk.ico')

icon.signal_connect('activate') do |ic|
  ic.blinking = false
  messages = $vk.messages_get :filters => 1
  messages.shift
  $max_id = messages.map { |m| m['mid'] }.max
end

menu = Gtk::Menu.new
quit = Gtk::ImageMenuItem.new(Gtk::Stock::QUIT)
quit.signal_connect('activate') { Gtk.main_quit }
mark_as_read = Gtk::ImageMenuItem.new('Mark all as read')
mark_as_read.signal_connect('activate') do
  icon.blinking = false
  messages = $vk.messages_get :filters => 1
  messages.shift
  m_ids = messages.map { |m| m['mid'] }.join(',')
  sleep 0.3
  $vk.messages_markAsRead :message_ids => m_ids
end
menu.append(mark_as_read)
menu.append(quit)
menu.show_all

icon.signal_connect('popup-menu') do |_, button, time|
  menu.popup(nil, nil, button, time)
end

$max_id = 0

Thread.new do
  while true do
    new_messages = $vk.messages_get(:filters => 1)
    count = new_messages.shift
    if count > 0
      max = new_messages.map { |m| m['mid'] }.max
      print "max: #{$max_id}, "
      puts "current: #{max}"
      if max > $max_id
        icon.blinking = count != 0
      end
    end
    sleep 15
  end
end

Gtk.main
