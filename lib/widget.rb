require 'vk-ruby'
require_relative 'icon'
require_relative 'friends'
require_relative 'helper'

class GLib::Object
  def self.create(*args)
    yield(new(*args))
  end

  def append(widget, expand: false, fill: false, padding: 3)
    self.pack_start(widget, expand, fill, padding)
  end
end

$labels = {
    :user => 'User:',
    :message => 'Message:'
}

$labels_size = $labels.map { |_, v| v.length }.max

class Widget
  def initialize
    @vk = Vkontakte.new
    @friends= Friends.new(@vk)
    @icon = Icon.new(@vk)
    @icon.start
  end

  def parse_uid(username)
    if !(uid = username.match(/<id(\d+)>$/)).nil?
      uid[1]
    elsif !(uid = username.match(/^(\d+)/)).nil?
      uid[1]
    elsif username.empty?
      raise 'user field is empty'
    else
      raise "cannot find user \"#{username}\""
    end
  end

  def simple_box(text_label, entity)
    Gtk::Label.create($labels[text_label]) do |label|
      entity.width_chars = 40
      label.width_chars = $labels_size
      label.xalign = 0
      label.yalign = 0.5
      if text_label == :user
        online_status(entity, label)
      end
      Gtk::HBox.create(false, 5) do |hbox|
        hbox.pack_start_defaults(label)
        hbox.pack_start_defaults(entity)
      end
    end
  end

  def online_status(user, label)
    user.signal_connect('focus_out_event') do
      Thread.new do
        begin
          usr = @vk.user(parse_uid(user.text), :fields => 'online')
          online = usr['online'] == 1
          label.markup = online ? "<span foreground='green'>#{label.text}</span>" : label.text
        rescue Exception => e
          puts e
        end
      end
      false
    end
  end

  def main_buttons(user, msg, history)
    Gtk::HBox.create(true, 0) do |buttons|
      buttons.append(left_buttons(user, history))
      buttons.append(right_buttons(user, msg, history))
    end
  end

  def refresh_history(user_text)
    begin
      uid = parse_uid(user_text)
      messages = @vk.messages_getHistory(:user_id => uid)
      user = @vk.user(uid, :fields => 'online')
      username = user['first_name']
      online = user['online'] == 1
      refresh_messages(messages, username, online)
    rescue Exception => e
      return "(#{e.message})"
    end
  end

  def refresh_messages(messages, username = nil, online = false)
    messages.shift
    if messages.empty?
      raise 'no messages yet'
    end
    messages.map do |msg|
      VkHelper.message(msg, username, online)
    end.join()
  end

  def history_button(text, user, history)
    Gtk::Button.create(text) do |button|
      button.signal_connect('clicked') do
        history.buffer.text = 'getting...'
        Thread.new do
          history.buffer.text = refresh_history(user.text)
        end
      end
      return button
    end
  end

  def new_messages_button(text, user, history)
    user.text = ''
    Gtk::Button.create(text) do |button|
      button.xalign=1.0
      button.signal_connect('clicked') do
        history.buffer.text = 'getting...'
        Thread.new do
          history.buffer.text = refresh_messages(@vk.messages_get)
        end
      end
      return button
    end
  end

  def left_buttons(user, history)
    Gtk::HBox.create(true, 0) do |buttons|
      buttons.append(history_button('Show history', user, history))
      buttons.append(new_messages_button('Show new', user, history))
    end
  end

  def right_buttons(user, msg, history)
    Gtk::HBox.create(true, 0) do |buttons|
      buttons.append(send_button('Send message', user, msg, history))
    end
  end

  def send_button(text, user, msg, history)
    Gtk::Button.create(text) do |button|
      button.signal_connect('clicked') do
        begin
          uid = parse_uid(user.text)
          mid = @vk.messages_send(:user_id => uid, :message => msg.text)
          usr = @vk.user(uid)['first_name']
          puts "Message ##{mid} for #{usr} has been sent"
          history.buffer.text = "Me:\nsending...\n\n" + history.buffer.text
          Thread.new do
            history.buffer.text = refresh_history(user.text)
          end
        rescue Exception => e
          history.buffer.text = "(#{e.message})"
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

  def history_textview(user)
    Gtk::TextView.create do |history|
      user.signal_connect('focus_out_event') do
        Thread.new do
          history.buffer.text = refresh_history(user.text)
        end
        false
      end
      history.left_margin = 10
      history.editable = false
      history.wrap_mode = Gtk::TextTag::WRAP_WORD
      history
    end
  end

  def user_completion
    users = Gtk::EntryCompletion.new
    model = Gtk::ListStore.new(String)
    @friends.each do |k, names|
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

  def mainbox
    Gtk::VBox.create(false, 0) do |main|
      user = Gtk::Entry.new
      msg = Gtk::Entry.new
      user.completion = user_completion
      main.append(simple_box(:user, user))
      main.append(simple_box(:message, msg))
      history = history_textview(user)
      main.append(main_buttons(user, msg, history))
      main.append(Gtk::HSeparator.new, fill: true)
      main.append(scrolled_win(history), expand: true, fill: true)
    end
  end
end