class Gtk::Widget
  def self.create(*args)
    yield(new(*args))
  end
end

def get_buttons(user, msg, history)
  Gtk::HBox.create(true, 0) do |buttons|
    buttons.pack_start(get_buttons_left(user, history), false, false, 3)
    buttons.pack_start(get_buttons_right(user, msg, history), false, false, 3)
  end
end

def get_buttons_left(user, history)
  Gtk::HBox.create(true, 0) do |buttons|
    buttons.pack_start(make_history_button('Show history', user, history), false, false, 3)
    buttons.pack_start(make_new_messages_button('Show new', user, history), false, false, 3)
  end
end

def get_buttons_right(user, msg, history)
  Gtk::HBox.create(true, 0) do |buttons|
    buttons.pack_start(make_send_button('Send message', user, msg, history), false, false, 3)
  end
end