class DayOne
  class << self
    attr_accessor :to_dayone_options
  end

  def to_dayone(options)
    DayOne.to_dayone_options ||= []
    DayOne.to_dayone_options << options
  end
end
