# encoding: utf-8
class Hash
  def deep_stringify_keys
    dup.deep_stringify_keys!
  end
  def deep_stringify_keys!
    keys.each do |key|
      val = delete(key)
      self[key.to_s] = val.is_a?(Hash) ? val.deep_stringify_keys : val
    end
    self
  end
end
