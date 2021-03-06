class Icon
  def initialize(vk, filename)
    @vk = vk
    @max_id = 0
    @icon = icon(filename)
    menu(@icon)
    start
  end

  def menu(icon)
    Gtk::Menu.create do |menu|
      quit = Gtk::ImageMenuItem.new(Gtk::Stock::QUIT)
      quit.signal_connect('activate') { Gtk.main_quit }
      mark_as_read = Gtk::ImageMenuItem.new('Mark all as read')
      mark_as_read.signal_connect('activate') do
        icon.blinking = false
        messages = @vk.messages_get :filters => 1
        messages.shift
        m_ids = messages.map { |m| m['mid'] }.join(',')
        sleep 0.3
        begin
          @vk.messages_markAsRead :message_ids => m_ids
        rescue Exception => e
          puts e
        end
      end
      menu.append(mark_as_read)
      menu.append(quit)
      menu.show_all

      icon.signal_connect('popup-menu') do |_, button, time|
        menu.popup(nil, nil, button, time)
      end
    end
  end

  def icon(filename)
    Gtk::StatusIcon.create do |icon|
      icon.pixbuf = Gdk::Pixbuf.new(filename)
      icon.signal_connect('activate') do |i|
        i.blinking = false
        messages = @vk.messages_get :filters => 1
        messages.shift
        @max_id = messages.map { |m| m['mid'] }.max
      end
    end
  end

  def start
    Thread.new do
      while true do
        new_messages = @vk.messages_get(:filters => 1)
        count = new_messages.shift
        if count > 0
          max = new_messages.map { |m| m['mid'] }.max
          print "max: #{@max_id}, "
          puts "current: #{max}"
          if max > @max_id
            @icon.blinking = count != 0
          end
        end
        sleep 15
      end
    end
  end
end

