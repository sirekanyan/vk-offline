class Gtk::Entry
  def async_signal(action, out: nil)
    signal_connect(action) do
      Thread.new do
        begin
          yield
        rescue Exception => e
          if out.nil?
            puts e.message
            puts e.backtrace
          else
            out.buffer.text = "(#{e.message})"
          end
        end
      end
      false
    end
  end
end

class Action
  def initialize(vk)
    @vk = vk
  end

  def update_online_status(user, label)
    user.async_signal('focus_out_event') do
      usr = @vk.user(VkHelper.parse_uid(user.text), :fields => 'online')
      online = usr['online'] == 1
      label.markup = online ? "<span foreground='green'>#{label.text}</span>" : label.text
    end
  end
end