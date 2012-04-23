require "mustache"

class MustacheRenderer
  def self.context_expander_source
    @@context_expander_source ||= File.read("views/context_expander.mustache")
  end

  def self.context_expander(is_top, is_bottom, line_number, is_incremental)
    context_extra_class = "topExpander" if is_top
    context_extra_class = "bottomExpander" if is_bottom
    context_extra_class ||= ""
    expand_inner_class = is_incremental ? "incrementalExpansion" : ""

    Mustache.render(context_expander_source,
        :context_extra_class => context_extra_class,
        :expand_inner_class => expand_inner_class,
        :line_number => line_number,
        :incremental => is_incremental)
  end
end
