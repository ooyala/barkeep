# Optionally patches all Exceptions to prune the length of the backtraces and to make each line shorter.
# This is to improve the developer experience, because our exceptions can be taller than one screen and
# each line can be long. For example:
#   ...
#   /Users/philc/.rbenv/versions/1.9.2-p290/lib/ruby/gems/1.9.1/gems/sequel-3.28.0/lib/sequel/adapters/mysql.rb:175:in `query'
#   /Users/philc/.rbenv/versions/1.9.2-p290/lib/ruby/gems/1.9.1/gems/sequel-3.28.0/lib/sequel/adapters/mysql.rb:175:in `block in _execute'
#   ...
#
# To use this, invoke BacktraceCleanear.monkey_patch_all_exceptions!
# If you want to access the full backtrace while debugging, use my_exception.full_backtrace.
class BacktraceCleaner

  def self.monkey_patch_all_exceptions!
    return if Exception.new.respond_to?(:backtrace_prior_to_backtrace_cleaner)

    Exception.class_eval do
      alias :backtrace_prior_to_backtrace_cleaner :backtrace
      alias :full_backtrace :backtrace_prior_to_backtrace_cleaner

      def backtrace
        backtrace = backtrace_prior_to_backtrace_cleaner
        return nil if backtrace.nil?
        filter_backtrace(prune_backtrace(backtrace))
      end

      def prune_backtrace(backtrace)
        # Our backtraces which involve gems can include many lines from within the gem's internals.
        # Collapse those long sequences of lines and include just the first and last line.
        current_gem = nil
        current_gem_line_number = nil
        i = backtrace.length - 1

        while i >= 0
          line_gem = gem_from_line(backtrace[i])
          if line_gem != current_gem || i == 0
            if current_gem && (current_gem_line_number - i) > 2
              backtrace[i..current_gem_line_number] =
                  [backtrace[i], "(...)", backtrace[current_gem_line_number]]
            end
            current_gem = line_gem
            current_gem_line_number = i
          end
          i -= 1
        end
        backtrace
      end

      # Returns the Rubygem which is part of the given backtrace line, or nil if the line does not include
      # a gem in it.
      def gem_from_line(backtrace_line)
        # Pull out "sequel-3.28.0" from this path: ".../lib/ruby/gems/1.9.1/gems/sequel-3.28.0/lib/..."
        (%r{/ruby/gems/[^/]+/gems/([^/]+)/}.match(backtrace_line) || [])[1]
      end

      def filter_backtrace(backtrace) backtrace.map { |line| filter_backtrace_line(line) } end

      def filter_backtrace_line(line)
        # Abbreviate those long gem paths, e.g.
        # /Users/philc/.rbenv/versions/1.9.2-p290/lib/ruby/gems/1.9.1/gems/sequel-3.28.0/lib =>
        #   .../gems/1.9.1/gems/sequel-3.28.0/lib
        line.sub(Gem.dir, "...")
      end
    end
  end
end