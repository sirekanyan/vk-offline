#!/usr/bin/env ruby
require 'gtk2'
Dir.chdir File.expand_path File.dirname($0)
require 'vk-ruby'

$vk = Vkontakte.new

def add_to_list friends
  online = friends.select{|u| u['online'] == 1}.count
  friends.each do |u|
    key = u['uid']
    first = u['first_name'] + ' ' + u['last_name']
    last = u['last_name'] + ' ' + u['first_name']
    if $users.has_key? key then
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

add_to_list($vk.friends_get(fields: 'uid', order: 'hints', fields: 'online'))
add_to_list($vk.friends_get(fields: 'uid', order: 'hints', fields: 'online', lang: 'ru'))

if File.exists?('friends.txt') then
  uids = File.read('friends.txt').split("\n")
  uids.each_slice(250) do |i|
    add_to_list($vk.users_get(user_ids: i.join(','), fields: 'online'))
    add_to_list($vk.users_get(user_ids: i.join(','), fields: 'online', lang: 'ru'))
  end
else
  puts '| You may specify more users with friends.txt file'
  puts '| Just create friends.txt file with list of user ids'
end

$labels = {:user => "User:", :msg => "Message:"}
$labels_size = $labels.map{|k,v| v.length}.max

def parse_uid username
  if u = username.match(/^(id)?(\d+)$/) then
    u[2]
  elsif u = username.match(/\<(id)?(\d+)\>$/) then
    u[2]
  elsif u = username.match(/^(\d+)/) then
    u[1]
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

def f_date d
  timedate = Time.at(d)
  date = timedate.to_date
  date = "today" if date == Date.today
  time = timedate.strftime("%T")
  "#{date} at #{time}"
end

def f_body b
  b += "\n" unless b.empty?
end

def f_video v
  "#{v['title']}\nhttps://vk.com/video#{v['owner_id']}_#{v['vid']}"
end

def f_photo p
  p['src_big']
end

def f_audio v
  "#{v['artist']} -- #{v['title']}\n#{v['url'].partition("?").first}"
end

def f_wall w
  "https://vk.com/wall#{w['to_id']}_#{w['id']}"
end

def f_doc d
  "#{d['title']}\nhttps://vk.com/doc#{d['owner_id']}_#{d['did']}"
end

def f_at at
  case at['type']
  when 'photo' then
    "photo:\n#{f_photo at['photo']}"
  when 'video' then
    "video:\n#{f_video at['video']}"
  when 'audio' then
    "audio:\n#{f_audio at['audio']}"
  when 'doc' then
    "doc:\n#{f_doc at['doc']}"
  when 'wall' then
    "wall:\n#{f_wall at['wall']}"
  else
    at.to_s
  end 
end

def f_attach a
  return '' if a == nil
  a.map{|at| f_at at}.join("\n") + "\n"
end

def f_message msg, usrname, online: false
  unread = msg['read_state'] == 0 ? "[unread] " : ""
  online = online && msg['out'] != 1 ? "[online] " : ""
  who = msg['out'] == 1 ? "Me" : usrname
  attach = f_attach msg['attachments']
  fwds = msg['fwd_messages']
  fwd = ''
  if !fwds.nil? then
    fwds.each do |f| 
      fwd += f_message( f, "fwd: #{f['uid']}" )
    end
  end
  return "#{online}#{unread}#{who} (#{f_date msg['date']}):\n#{f_body msg['body']}#{attach}#{fwd}"
end

def refresh_history uid
  buff = ""
  usrname = ""
  online = false
  if uid then
    user = $vk.users_get(:user_id => uid, :fields => 'online').first
    if user == -1 then
      buff = [-1]
    else
      usrname = user['first_name']
      online = user['online'] == 1
      buff = $vk.messages_getHistory(:user_id => uid)
    end
  end
  ans = buff.shift
  buff_temp = ""
  buff.each do |msg|
    buff_temp += f_message(msg, usrname, online: online) + "\n"
  end
  buff_temp = "(no messages yet)" if buff.empty?
  buff_temp = "(check user id)" if ans == -1
  return buff_temp
end

def refresh_new_msgs uid
  buff = $vk.messages_get()
  ans = buff.shift
  buff_temp = ""
  buff.each do |msg|
    buff_temp += f_message(msg, msg['uid']) + "\n"
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

def make_new_msgs_button text, user, history
  user.text = ""
  button = Gtk::Button.new(text)
  button.xalign=1.0
  button.signal_connect("clicked") {
    history.buffer.text = "getting..."
    Thread.new {
      uid = parse_uid(user.text)
      history.buffer.text = refresh_new_msgs(uid)
    }
  }
  button
end

def get_buttons user, msg, history
  buttonsbox = Gtk::HBox.new(true, 0)
  buttonsbox.pack_start(get_buttons1(user, msg, history), false, false, 3)
  buttonsbox.pack_start(get_buttons2(user, msg, history), false, false, 3)
  buttonsbox
end

def get_buttons1 user, msg, history
  buttonsbox = Gtk::HBox.new(true, 0)
  buttonsbox.pack_start(make_history_button("Show history", user, history), false, false, 3)
  buttonsbox.pack_start(make_new_msgs_button("Show new", user, history), false, false, 3)
  buttonsbox
end

def get_buttons2 user, msg, history
  buttonsbox = Gtk::HBox.new(false, 0)
  buttonsbox.pack_start(make_send_button("Send message", user, msg, history), false, false, 3)
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

icon = Gtk::StatusIcon.new
icon.pixbuf = Gdk::Pixbuf.new('vk.ico')

icon.signal_connect('activate') do |icon|
  icon.blinking = false
  msgs = $vk.messages_get :filters => 1
  msgs.shift
  $max_id = msgs.map{|m| m['mid']}.max
end

menu = Gtk::Menu.new
quit = Gtk::ImageMenuItem.new(Gtk::Stock::QUIT)
quit.signal_connect('activate'){ Gtk.main_quit }
mark_as_read = Gtk::ImageMenuItem.new("Mark all as read")
mark_as_read.signal_connect('activate') do
  icon.blinking = false
  msgs = $vk.messages_get :filters => 1
  msgs.shift
  mids = msgs.map{|m| m['mid']}.join(',')
  sleep 0.3
  $vk.messages_markAsRead :message_ids => mids  
end
menu.append(mark_as_read)
menu.append(quit)
menu.show_all

icon.signal_connect('popup-menu') do |icon, button, time|
  menu.popup(nil, nil, button, time)
end

$max_id = 0

Thread.new {
  while(true) do
    new_msgs = $vk.messages_get(:filters => 1)
    count = new_msgs.shift
    if count > 0 then
      max = new_msgs.map{|m| m['mid']}.max
      print "max: #{$max_id}, "
      puts "current: #{max}"
      if max > $max_id then
        icon.blinking = count != 0
      end
    end
    sleep 15
  end
}

Gtk.main
