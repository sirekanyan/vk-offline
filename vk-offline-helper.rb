require 'erb'
require 'ostruct'

$templates = {
    photo: '<%= src_big %>',
    video: '<%= title %> => https://vk.com/video<%= owner_id %>_<%= vid %>',
    audio: '<%= artist %> -- <%= title %> => <%= url.partition(\'?\').first %>',
    doc:   '<%= title %> => https://vk.com/doc<%= owner_id %>_<%= did %>',
    wall:  'https://vk.com/wall<%= to_id %>_<%= id %>'
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
    ":#{@type} => #{render_body}"
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

class Hash
  def to_vk_message(username, online: false)
    unread = self['read_state'] == 0 ? '[unread] ' : ''
    online = online && self['out'] != 1 ? '[online] ' : ''
    who = self['out'] == 1 ? 'Me' : username
    attach = VkAttachments.new self['attachments']
    forwards = self['fwd_messages']
    fwd = ''
    unless forwards.nil?
      forwards.each do |f|
        fwd += f.to_vk_message("fwd: #{f['uid']}")
      end
    end
    "#{online}#{unread}#{who} (#{self['date'].to_vk_date}):\n#{self['body'].to_vk_body}#{attach}#{fwd}"
  end
end
