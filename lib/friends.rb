require 'vk-ruby'

class Friends
  def initialize(vk)
    @vk = vk
    @friends = {}
    load_friends(fields: 'uid', order: 'hints')
    load_friends_from_file('friends.txt')
  end

  def each
    @friends.each do |friend|
      yield(friend)
    end
  end

  private

  def load_friends(args)
    load(@vk.friends_get(args))
    load(@vk.friends_get(args.merge(lang: 'ru')))
  end

  def load_users(args)
    load(@vk.users_get(args))
    load(@vk.users_get(args.merge(lang: 'ru')))
  end

  def load_friends_from_file(filename)
    if File.exists?(filename)
      File.read(filename).split("\n").each_slice(250) do |i|
        load_users(user_ids: i.join(','))
      end
    end
  end

  def load(users)
    users.each do |u|
      key = u['uid']
      first = u['first_name'] + ' ' + u['last_name']
      last = u['last_name'] + ' ' + u['first_name']
      if @friends.has_key? key
        @friends[key] += [first, last]
      else
        @friends[key] = [first, last]
      end
    end
    puts "#{users.count} friends added"
  end
end