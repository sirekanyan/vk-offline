require 'erb'
require 'ostruct'

$templates = {
    photo: '<%= src_big %>',
    video: '<%= title %> => https://vk.com/video<%= owner_id %>_<%= vid %>',
    audio: '<%= artist %> -- <%= title %> => <%= url.partition(\'?\').first %>',
    doc:   '<%= title %> => https://vk.com/doc<%= owner_id %>_<%= did %>',
    wall:  'https://vk.com/wall<%= to_id %>_<%= id %>',
    headers: '<%= unread %><%= who %> (<%= date %>):',
    message: "<%= body %><%= attach %><%= fwd %>\n"
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
  def self.parse_uid(username)
    if !(uid = username.match(/<id(\d+)>$/)).nil?
      uid[1]
    elsif !(uid = username.match(/^(\d+)/)).nil?
      uid[1]
    elsif username.empty?
      raise 'user field is empty'
    else
      raise "cannot find user \"#{username}\""
    end
  end

  def VkHelper.forwards(content)
    fwd = ''
    unless content.nil?
      content.each do |f|
        fwd += self.message(f, "fwd: #{f['uid']}")
      end
    end
    fwd
  end

  def VkHelper.headers(message, username)
    Replacer.new(
        unread: message['read_state'] == 0 ? '[unread] ' : '',
        who:    message['out'] == 1 ? 'Me' : username,
        date:   message['date'].to_vk_date
    ).render($templates[:headers])
  end

  def VkHelper.body(message)
    Replacer.new(
        body: message['body'],
        attach: VkAttachments.new(message['attachments']),
        fwd: forwards(message['fwd_messages'])
    ).render($templates[:message])
  end

  def VkHelper.message(message, username)
    username = message['uid'] if username.nil?
    self.headers(message, username) + "\n" + self.body(message)
  end
end
