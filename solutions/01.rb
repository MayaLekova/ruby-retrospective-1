class Array
  def to_hash
    ret_hash = {}
    self.map { |pair| ret_hash[pair[0]] = pair[1] }
    ret_hash
  end
  
  def index_by
    ret_hash = {}
    each { |x| ret_hash[yield x] = x }
    ret_hash
  end
  
  def subarray_count(arr)
    each_cons(arr.length).count(arr)
  end
  
  def occurences_count
    ret_hash = Hash.new(0)
    each { |x| ret_hash[x] += 1 }
    ret_hash
  end
end
