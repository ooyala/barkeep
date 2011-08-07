# Hard-coded information about keyboard shortcuts

module KeyboardShortcuts
	GLOBAL_SHORTCUTS = {
		"c" => "Commits",
		"m" => "My profile",
		"?" => "Open shortcut list"
	}

	# View-specific shortcuts
	COMMIT_SEARCH_SHORTCUTS = {
		"j" => "Next commit",
		"k" => "Previous commit",
		"l" => "Next page of results",
		"h" => "Previous page of results",
		"/" => "Focus search box",
		"enter" => "Go to commit"
	}

	COMMIT_SHORTCUTS = {
		"j" => "Scroll down",
		"k" => "Scroll up",
		"n" => "Next file in commit",
		"p" => "Previous file in commit"
	}

	def self.shortcuts(view)
		result = [{ "Global" => GLOBAL_SHORTCUTS }]
		case view
		when /^commits$/i
			result << { "Commit Search" => COMMIT_SEARCH_SHORTCUTS }
		when /^commits\/\S{40}$/i
			result << { "Commit" => COMMIT_SHORTCUTS }
		else
			result << nil
		end
	end
end
