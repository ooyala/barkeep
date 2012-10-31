# Hard-coded information about keyboard shortcuts

module KeyboardShortcuts
  GLOBAL_SHORTCUTS = {
    "c" => "Commits",
    "s" => "Stats",
    "i" => "Inspire",
    "?" => "Open shortcut list"
  }

  # View-specific shortcuts
  COMMIT_SEARCH_SHORTCUTS = {
    "r" => "Refresh saved searches",
    "j" => "Next commit",
    "k" => "Previous commit",
    "l" => "Next page of results",
    "h" => "Previous page of results",
    "/" => "Focus search box",
    "o or enter" => "Go to commit"
  }

  COMMIT_SHORTCUTS = {
    "j" => "Select next line",
    "k" => "Select previous line",
    "shift + n" => "Next file in commit",
    "shift + p" => "Previous file in commit",
    "enter" => "New comment on selected line",
    "shift + c" => "Add a commit comment",
    "ctrl + shift + p" => "Toggle comment preview",
    "n" => "Next diff chunk in commit",
    "p" => "Previous diff chunk in commit",
    "a then a" => "Toggle approval of commit",
    "e" => "Show full diff view",
    "b" => "Toggle side-by-side diff view",
    "r" => "Request code review",
    "h" => "Hide/Show comments"
  }

  def self.shortcuts(view)
    result = [{ "Global" => GLOBAL_SHORTCUTS }]
    case view
    when %r{^commits$}i
      result << { "Commit Search" => COMMIT_SEARCH_SHORTCUTS }
    when %r{^commits/[^/]+/\S{40}$}i
      result << { "Commit" => COMMIT_SHORTCUTS }
    else
      result << nil
    end
  end
end
