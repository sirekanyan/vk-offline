class ::Hash
  def to_obj
    self.each do |k, v|
      if v.kind_of? Hash
        v.to_obj
      end
      self.instance_variable_set("@#{k}", v)
      self.class.send(:define_method, k, proc { self.instance_variable_get("@#{k}") })
      self.class.send(:define_method, "#{k}=", proc { |vv| self.instance_variable_set("@#{k}", vv) })
    end
  end
end

class ::Array
  def to_obj
    self.each do |i|
      if i.kind_of? Hash
        i.to_obj
      end
    end
  end
end
