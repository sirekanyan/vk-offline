class Gtk::Widget
  def self.create(*args)
    yield(new(*args))
  end

  def append(widget, expand: false, fill: false, padding: 3)
    self.pack_start(widget, expand, fill, padding)
  end
end

def simple_box(text_label, entity)
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

def main_buttons(user, msg, history)
  Gtk::HBox.create(true, 0) do |buttons|
    buttons.append(left_buttons(user, history))
    buttons.append(right_buttons(user, msg, history))
  end
end

def left_buttons(user, history)
  Gtk::HBox.create(true, 0) do |buttons|
    buttons.append(make_history_button('Show history', user, history))
    buttons.append(make_new_messages_button('Show new', user, history))
  end
end

def right_buttons(user, msg, history)
  Gtk::HBox.create(true, 0) do |buttons|
    buttons.append(make_send_button('Send message', user, msg, history))
  end
end
