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
