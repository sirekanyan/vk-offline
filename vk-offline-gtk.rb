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

uids = File.read('friends.txt').split("\n")
uids.each_slice(250) do |i|
  add_to_list($vk.users_get(user_ids: i.join(','), fields: 'online'))
end

$users.uniq!

$labels = {:user => "User:", :msg => "Message:"}
$labels_size = $labels.map{|k,v| v.length}.max

def parse_uid username
  if u = username.match(/^(id)?(\d+)$/) then
    uid = u[2]
  elsif u = username.match(/\<(id)?(\d+)\>$/) then
    uid = u[2]     
  end
end

def make_box text_label, entity
  entity.width_chars = 30
  label = Gtk::Label.new(text_label)
  label.width_chars = $labels_size
  label.set_alignment(0, 0.5)
  hbox = Gtk::HBox.new(false, 5)
  hbox.pack_start_defaults(label)
  hbox.pack_start_defaults(entity)
  hbox
end

def completion user
  users = Gtk::EntryCompletion.new
  model = Gtk::ListStore.new(String)
  $users.each do |v|
    iter = model.append
    iter[0] = v
  end
  users.model = model
  users.text_column = 0
  users
end

def make_send_button text, user, msg
  button = Gtk::Button.new(text)
  button.signal_connect("clicked") {
    uid = parse_uid(user.text)
    if uid then
      mid = $vk.messages_send(:user_id => uid, :message => msg.text)
      usr = $vk.user(uid)['first_name']
      puts "Message ##{mid} for #{usr} has been sent"
    end
  }
  button
end

def make_history_button text, user
  button = Gtk::Button.new(text)
  button.signal_connect("clicked") {
    puts "Show history for user #{user.text}"
  }
  button
end

window = Gtk::Window.new
window.set_title  "Send message"
window.border_width = 10
window.signal_connect('delete_event') { Gtk.main_quit }

mainbox = Gtk::VBox.new(false, 0)

user = Gtk::Entry.new
user.completion = completion user
msg = Gtk::Entry.new
mainbox.pack_start(make_box("User:", user), false, false, 3)
mainbox.pack_start(make_box("Message:", msg), false, false, 3)
mainbox.pack_start(Gtk::HSeparator.new, false, true, 3)

buttonsbox = Gtk::HBox.new(false, 0)
buttonsbox.pack_start(make_history_button("Show history", user), false, false, 3)
buttonsbox.pack_start(make_send_button("Send", user, msg), false, false, 3)
mainbox.pack_start(buttonsbox, false, false, 0)

window.add(mainbox)
window.show_all
Gtk.main
