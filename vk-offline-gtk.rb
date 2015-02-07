#!/usr/bin/env ruby
require 'gtk2'
require_relative 'lib/widget'

class VkontakteOffline < Gtk::Window
  def initialize
    super
    set_title 'Offline Messenger'
    set_size_request 420, 500
    set_border_width 10
    signal_connect('delete_event') { Gtk.main_quit }
    add Widget.new.mainbox
    show_all
  end
end

VkontakteOffline.new
Gtk.main