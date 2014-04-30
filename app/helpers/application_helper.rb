module ApplicationHelper

  def flash_class(level)
    case level
      when :notice then "note note-info"
      when :success then "note note-success"
      when :error then "note note-danger"
      when :alert then "note note-warning"
    end
  end
end