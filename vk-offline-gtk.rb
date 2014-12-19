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

$labels = {:user => 'User:', :msg => 'Message:'}
$labels_size = $labels.map { |_, v| v.length }.max

def parse_uid(username)
  if u = username.match(/<id(\d+)>$/)
    u[1]
  elsif u = username.match(/^(\d+)/)
    u[1]
  else
    nil
  end
end

def make_box(text_label, entity)
  Gtk::Label.create(text_label) do |label|
    entity.width_chars = 40
    label.width_chars = $labels_size
    label.set_alignment(0, 0.5)
    Gtk::HBox.create(false, 5) do |hbox|
      hbox.pack_start_defaults(label)
      hbox.pack_start_defaults(entity)
    end
  end
end

def get_user_with_completion(user)
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
  user.completion = users
  user
end

def make_send_button(text, user, msg, history)
  Gtk::Button.create(text) do |button|
    button.signal_connect('clicked') do
      uid = parse_uid(user.text)
      unless uid.nil?
        mid = $vk.messages_send(:user_id => uid, :message => msg.text)
        usr = $vk.user(uid)['first_name']
        puts "Message ##{mid} for #{usr} has been sent"
        history.buffer.text = "Me:\nsending...\n\n" + history.buffer.text
        Thread.new {
          history.buffer.text = refresh_history(uid)
        }
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
      vbox.pack_start(scrolled_win, true, true, 0)
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

def make_history_button(text, user, history)
  Gtk::Button.create(text) do |button|
    button.signal_connect('clicked') do
      history.buffer.text = 'getting...'
      Thread.new do
        uid = parse_uid(user.text)
        history.buffer.text = refresh_history(uid) unless uid.nil?
        history.buffer.text = '(no messages)' if uid.nil?
      end
    end
    return button
  end
end

def make_new_messages_button(text, user, history)
  user.text = ''
  button = Gtk::Button.new(text)
  button.xalign=1.0
  button.signal_connect('clicked') {
    history.buffer.text = 'getting...'
    Thread.new {
      uid = parse_uid(user.text)
      history.buffer.text = refresh_new_msgs(uid)
    }
  }
  button
end

def get_history_textview(user)
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
    user = get_user_with_completion(Gtk::Entry.new)
    msg = Gtk::Entry.new
    mainbox.pack_start(make_box('User:', user), false, false, 3)
    mainbox.pack_start(make_box('Message:', msg), false, false, 3)
    history = get_history_textview(user)
    mainbox.pack_start(get_buttons(user, msg, history), false, false, 5)
    mainbox.pack_start(Gtk::HSeparator.new, false, true, 3)
    mainbox.pack_start(scrolled_win(history), true, true, 5)
    return mainbox
  end
end

Gtk::Window.create do |window|
  window.set_title 'Offline Messenger'
  window.set_size_request(420, 500)
  window.border_width = 10
  window.signal_connect('delete_event') { Gtk.main_quit }
  window.add(get_mainbox)
  window.show_all
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
  mids = messages.map { |m| m['mid'] }.join(',')
  sleep 0.3
  $vk.messages_markAsRead :message_ids => mids
end
menu.append(mark_as_read)
menu.append(quit)
menu.show_all

icon.signal_connect('popup-menu') do |_, button, time|
  menu.popup(nil, nil, button, time)
end

$max_id = 0

Thread.new {
  while true do
    new_msgs = $vk.messages_get(:filters => 1)
    count = new_msgs.shift
    if count > 0
      max = new_msgs.map { |m| m['mid'] }.max
      print "max: #{$max_id}, "
      puts "current: #{max}"
      if max > $max_id
        icon.blinking = count != 0
      end
    end
    sleep 15
  end
}

Gtk.main
