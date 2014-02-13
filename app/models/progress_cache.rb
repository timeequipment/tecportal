class ProgressCache
  include ApplicationHelper
  
  def initialize(name, steps)
    @name = name
    @steps = steps
    @progress = 0
    save
  end

  def step
    @progress += 1
    save
  end

  def complete
    @progress = @steps
    save
  end

  def save
    cache_save @name, "#{ @progress }/#{ @steps }"
  end

end
