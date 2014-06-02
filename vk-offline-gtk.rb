#!/usr/bin/env ruby
require 'gtk2'
Dir.chdir File.expand_path File.dirname($0)
require 'vk-ruby'

$vk = Vkontakte.new

def add_to_list friends
  online = friends.select{|u| u['online'] == 1}.count
  $users += friends.map{|u| "#{u['first_name']} #{u['last_name']} <id#{u['uid']}>"}
  $users += friends.map{|u| "#{u['last_name']} #{u['first_name']} <id#{u['uid']}>"}
  $online += online
  puts "#{friends.count} friends added, online: #{online}"
end

$users = []
$online = 0

add_to_list($vk.friends_get(fields: 'uid', order: 'hints', fields: 'online'))

if File.exists?('friends.txt') then
  uids = File.read('friends.txt').split("\n")
  uids.each_slice(250) do |i|
    add_to_list($vk.users_get(user_ids: i.join(','), fields: 'online'))
  end
else
  puts '| You may specify more users with friends.txt file'
  puts '| Just create friends.txt file with list of user ids'
end

$users.uniq!

$labels = {:user => "User:", :msg => "Message:"}
$labels_size = $labels.map{|k,v| v.length}.max

def parse_uid username
  if u = username.match(/^(id)?(\d+)$/) then
    u[2]
  elsif u = username.match(/\<(id)?(\d+)\>$/) then
    u[2]
  else
    nil     
  end
end

def make_box text_label, entity
  entity.width_chars = 40
  label = Gtk::Label.new(text_label)
  label.width_chars = $labels_size
  label.set_alignment(0, 0.5)
  hbox = Gtk::HBox.new(false, 5)
  hbox.pack_start_defaults(label)
  hbox.pack_start_defaults(entity)
  hbox
end

def get_user_with_completion user
  users = Gtk::EntryCompletion.new
  model = Gtk::ListStore.new(String)
  $users.each do |v|
    iter = model.append
    iter[0] = v
  end
  users.model = model
  users.text_column = 0
  user.completion = users
  return user
end

def make_send_button text, user, msg, history
  button = Gtk::Button.new(text)
  button.signal_connect("clicked") {
    uid = parse_uid(user.text)
    if !uid.nil? then
      mid = $vk.messages_send(:user_id => uid, :message => msg.text)
      usr = $vk.user(uid)['first_name']
      puts "Message ##{mid} for #{usr} has been sent"
      history.buffer.text = "Me:\nsending...\n\n" + history.buffer.text
      Thread.new {
        history.buffer.text = refresh_history(uid)
      }
    end
  }
  button
end

def scrolled_win textview
  scrolled_win = Gtk::ScrolledWindow.new
  scrolled_win.add(textview)
  scrolled_win.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_ALWAYS)
  vbox = Gtk::VBox.new(false, 5)
  vbox.pack_start(scrolled_win, true,  true, 0)
  return vbox
end

def format_message msg, usrname
  unread = (msg['read_state'] == 0 ? "*" : "")
  if msg['out'] == 1 then
    who = "#{unread}Me:\n"
  else
    who = "#{unread}#{usrname}:\n"
  end
  attach = ""
  if msg['attachment'] then
    attach = "(attachment)\n"
  end
  body = msg['body']
  body += "\n" unless body.empty?
  body += msg.to_s + "\n" if body.empty?
  return who + body + attach + "\n"
end

def refresh_history uid
  buff = ""
  usrname = ""
  if uid then
    users = $vk.users([uid])
    if users == -1 then
      buff = [-1]
    else
      usrname = users.first['first_name']
      buff = $vk.messages_getHistory(:user_id => uid)
    end
  end
  ans = buff.shift
  buff_temp = ""
  buff.each do |msg|
    buff_temp += format_message(msg, usrname)
  end
  buff_temp = "(no messages yet)" if buff.empty?
  buff_temp = "(check user id)" if ans == -1
  return buff_temp
end

def make_history_button text, user, history
  button = Gtk::Button.new(text)
  button.signal_connect("clicked") {
    history.buffer.text = "getting..."
    Thread.new {
      uid = parse_uid(user.text)
      history.buffer.text = refresh_history(uid) unless uid.nil?
      history.buffer.text = '(no messages)' if uid.nil?
    }
  }
  button
end

def get_buttons user, msg, history
  buttonsbox = Gtk::HBox.new(false, 0)
  buttonsbox.pack_start(make_send_button("Send message", user, msg, history), false, false, 3)
  buttonsbox.pack_start(make_history_button("Show history", user, history), false, false, 3)
  buttonsbox
end

def get_history_textview user
  history = Gtk::TextView.new
  user.signal_connect("focus_out_event") {
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
  history
end

def get_mainbox
  mainbox = Gtk::VBox.new(false, 0)
  user = get_user_with_completion(Gtk::Entry.new)
  msg = Gtk::Entry.new
  mainbox.pack_start(make_box("User:", user), false, false, 3)
  mainbox.pack_start(make_box("Message:", msg), false, false, 3)
  history = get_history_textview(user)
  mainbox.pack_start(get_buttons(user, msg, history), false, false, 5)
  mainbox.pack_start(Gtk::HSeparator.new, false, true, 3)
  mainbox.pack_start(scrolled_win(history), true, true, 5)
end

window = Gtk::Window.new
window.set_title  "Offline Messenger"
window.set_size_request(420, 500)
window.border_width = 10
window.signal_connect('delete_event') { Gtk.main_quit }
window.add(get_mainbox)
window.show_all
Gtk.main
