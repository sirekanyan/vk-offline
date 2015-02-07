require 'vk-ruby'
require_relative 'icon'
require_relative 'friends'
require_relative 'helper'
require_relative 'action'

class GLib::Object
  def self.create(*args)
    object = self.new *args
    yield object
    object
  end

  def append(widget, expand: false, fill: false, padding: 3)
    self.pack_start(widget, expand, fill, padding)
  end
end

$labels = {
    user: 'User:',
    message: 'Message:'
}

$labels_size = $labels.map { |_, v| v.length }.max

class Widget
  def initialize
    @vk = Vkontakte.new
    @friends = Friends.new(@vk)
    @action = Action.new(@vk)
    Icon.new(@vk, 'vk.ico').start
  end

  def simple_box(text_label, entity)
    Gtk::HBox.create(false, 5) do |hbox|
      Gtk::Label.create($labels[text_label]) do |label|
        entity.width_chars = 40
        label.width_chars = $labels_size
        label.xalign = 0
        label.yalign = 0.5
        if text_label == :user
          @action.update_online_status(entity, label)
        end
        hbox.pack_start_defaults(label)
        hbox.pack_start_defaults(entity)
      end
    end
  end

  def buttons(user, msg, history)
    Gtk::HBox.create(true, 0) do |buttons|
      Gtk::HBox.create(true, 0) do |left|
        left.append(history_button('Show history', user, history))
        left.append(new_messages_button('Show new', user, history))
        buttons.append(left)
      end
      Gtk::HBox.create(true, 0) do |right|
        right.append(send_button('Send message', user, msg, history))
        buttons.append(right)
      end
    end
  end

  def history_button(text, user, history)
    Gtk::Button.create(text) do |button|
      @action.click_history_button(button, user, history)
      return button
    end
  end

  def new_messages_button(text, user, history)
    user.text = ''
    Gtk::Button.create(text) do |button|
      button.xalign = 1.0
      @action.show_new_messages(button, history)
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
      @action.send_message(button, user, msg, history)
    end
  end

  def scrolled_win(textview)
    Gtk::VBox.create(false, 5) do |vbox|
      Gtk::ScrolledWindow.create do |scrolled_win|
        scrolled_win.add(textview)
        scrolled_win.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_ALWAYS)
        vbox.pack_start_defaults(scrolled_win)
      end
    end
  end

  def history_textview(user)
    Gtk::TextView.create do |history|
      @action.focus_out_user(history, user)
      history.left_margin = 10
      history.editable = false
      history.wrap_mode = Gtk::TextTag::WRAP_WORD
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
      main.append(buttons(user, msg, history))
      main.append(Gtk::HSeparator.new, fill: true)
      main.append(scrolled_win(history), expand: true, fill: true)
      main.append(simplest_box(:user, user))
    end
  end
end