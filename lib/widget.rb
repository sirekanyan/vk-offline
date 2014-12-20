class Gtk::Widget
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

def simple_box(text_label, entity)
  Gtk::Label.create($labels[text_label]) do |label|
    entity.width_chars = 40
    label.width_chars = $labels_size
    label.set_alignment(0, 0.5)
    Gtk::HBox.create(false, 5) do |hbox|
      hbox.pack_start_defaults(label)
      hbox.pack_start_defaults(entity)
    end
  end
end

def main_buttons(user, msg, history)
  Gtk::HBox.create(true, 0) do |buttons|
    buttons.append(left_buttons(user, history))
    buttons.append(right_buttons(user, msg, history))
  end
end

def history_button(text, user, history)
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

def new_messages_button(text, user, history)
  user.text = ''
  Gtk::Button.create(text) do |button|
    button.xalign=1.0
    button.signal_connect('clicked') do
      history.buffer.text = 'getting...'
      Thread.new do
        uid = parse_uid(user.text)
        history.buffer.text = refresh_new_msgs(uid)
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