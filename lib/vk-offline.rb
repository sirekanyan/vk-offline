require 'vk-ruby'

class VkontakteOffline
  attr_reader :users, :vk

  def initialize
    @vk = Vkontakte.new
    @users = {}
  end

  def load_users(args)
    load(@vk.users_get(args))
    load(@vk.users_get(args.merge(lang: 'ru')))
  end

  def load_friends(args)
    load(@vk.friends_get(args))
    load(@vk.friends_get(args.merge(lang: 'ru')))
  end

  private

  def load(users)
    users.each do |u|
      key = u['uid']
      first = u['first_name'] + ' ' + u['last_name']
      last = u['last_name'] + ' ' + u['first_name']
      if @users.has_key? key
        @users[key] += [first, last]
      else
        @users[key] = [first, last]
      end
    end
    puts "#{users.count} friends added"
  end
end