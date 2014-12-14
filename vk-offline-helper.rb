require 'erb'
require 'ostruct'

$templates = {
    photo: '<%= src_big %>',
    video: '<%= title %> => https://vk.com/video<%= owner_id %>_<%= vid %>',
    audio: '<%= artist %> -- <%= title %> => <%= url.partition(\'?\').first %>',
    doc:   '<%= title %> => https://vk.com/doc<%= owner_id %>_<%= did %>',
    wall:  'https://vk.com/wall<%= to_id %>_<%= id %>',
    headers: '<%= online %><%= unread %><%= who %> (<%= date %>):',
    message: '<%= body %><%= attach %><%= fwd %>'
}

class Replacer < OpenStruct
  def render(template)
    ERB.new(template).result(binding)
  end
end

class VkAttachment
  def initialize(attachment)
    @type = attachment['type']
    @body = attachment[@type]
  end

  def render_body
    replacer = Replacer.new(@body)
    replacer.render($templates[@type.to_sym])
  end

  def to_s
    "[#{@type}] => #{render_body}"
  end
end

class VkAttachments
  def initialize(attachments)
    if attachments.nil?
      @attachments = []
    else
      @attachments = attachments.map do |a|
        VkAttachment.new(a)
      end
    end
  end

  def to_s
    @attachments.join("\n") + "\n"
  end
end

class String
  def to_vk_body
    self + "\n" unless self.empty?
  end
end

class Fixnum
  def to_vk_date
    time_date = Time.at(self)
    date = time_date.to_date
    date = 'today' if date == Date.today
    time = time_date.strftime('%T')
    "#{date} at #{time}"
  end
end

class VkHelper
  def VkHelper.forwards(content)
    fwd = ''
    unless content.nil?
      content.each do |f|
        fwd += self.message(f, "fwd: #{f['uid']}")
      end
    end
    fwd
  end

  def VkHelper.headers(message, username, online)
    Replacer.new(
        unread: message['read_state'] == 0 ? '[unread] ' : '',
        online: online && message['out'] != 1 ? '[online] ' : '',
        who:    message['out'] == 1 ? 'Me' : username,
        date:   message['date'].to_vk_date
    ).render($templates[:headers])
  end

  def VkHelper.body(message)
    Replacer.new(
        body: message['body'].to_vk_body,
        attach: VkAttachments.new(message['attachments']),
        fwd: forwards(message['fwd_messages'])
    ).render($templates[:message])
  end

  def VkHelper.message(message, username, online: false)
    self.headers(message, username, online) + "\n" + self.body(message)
  end
end
