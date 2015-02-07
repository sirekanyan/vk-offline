class Gtk::Widget
  def async_signal(action)
    signal_connect(action) do
      Thread.new do
        yield
      end
      false
    end
  end

  def signal_simple(action)
    async_signal(action) do
      begin
        yield
      rescue Exception => e
        puts e.message
        puts e.backtrace
      end
    end
  end

  def signal_with_buffer(action, buffer)
    async_signal(action) do
      begin
        buffer.text = yield
      rescue Exception => e
        buffer.text = "(#{e.message})"
      end
    end
  end
end

class Action
  def initialize(vk)
    @vk = vk
  end

  def update_online_status(user, label)
    user.signal_simple('focus_out_event') do
      usr = @vk.user(VkHelper.parse_uid(user.text), :fields => 'online')
      online = usr['online'] == 1
      label.markup = online ? "<span foreground='green'>#{label.text}</span>" : label.text
    end
  end

  def refresh_messages(messages, username = nil)
    messages.shift
    if messages.empty?
      raise 'no messages yet'
    end
    messages.map do |msg|
      VkHelper.message(msg, username)
    end.join()
  end

  def refresh_history(user_text)
    begin
      uid = VkHelper.parse_uid(user_text)
      messages = @vk.messages_getHistory(:user_id => uid)
      user = @vk.user(uid, :fields => 'online')
      refresh_messages(messages, user['first_name'])
    rescue Exception => e
      return "(#{e.message})"
    end
  end

  def refresh_history2(history, user)
    Thread.new do
      history.buffer.text = refresh_history(user.text)
    end
  end

  def send_message(button, user, msg, history)
    button.signal_connect('clicked') do
      begin
        uid = VkHelper.parse_uid(user.text)
        mid = @vk.messages_send(:user_id => uid, :message => msg.text)
        usr = @vk.user(uid)['first_name']
        puts "Message ##{mid} for #{usr} has been sent"
        history.buffer.text = "Me:\nsending...\n\n" + history.buffer.text
        refresh_history2(history, user)
      rescue Exception => e
        history.buffer.text = "(#{e.message})"
      end
    end
  end

  def hist_upd(button, user, history, action)
    button.signal_with_buffer(action, history.buffer) do
      refresh_history(user.text)
    end
  end

  def click_history_button(button, user, history)
    hist_upd(button, user, history, 'clicked')
  end

  def focus_out_user(history, user)
    hist_upd(user, user, history, 'focus_out_event')
  end

  def show_new_messages(button, history)
    button.signal_with_buffer('clicked', history.buffer) do
      refresh_messages(@vk.messages_get)
    end
  end
end