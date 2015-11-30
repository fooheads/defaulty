# 
# Needed in order to make diff work for StringIO objects
#  
class StringIO
  def ==(o)
    self.read == o.read
  end
end

