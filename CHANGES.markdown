Barkeep Changes
===============

This file summarizes changes between tagged Barkeep versions. It lists tags in reverse chronological order.
Each tag is followed by a description of the changes it represents. This is not in a typical Changelog format,
but rather general markdown text describing important notes about the versions and progress of Barkeep.

0.1.1
-----

### Minor features and bugfixes

* [Fixed a confusing saved search title bug where the branch name was omitted](https://github.com/ooyala/barkeep/issues/76)
* [Commenter names are bold in comment emails to make them easier to spot](https://github.com/ooyala/barkeep/commit/b90d5130ac0cc83e1bbfd3314ebe433a28367d49)
* Better instructions for running Barkeep locally
* [Exclude commits from the saved search view that are not yet in the DB](https://github.com/ooyala/barkeep/issues/73)
* [Fixed the seam on the background image](https://github.com/ooyala/barkeep/issues/45)
* [Java is now syntax-highlighted](https://github.com/ooyala/barkeep/commit/a32656a99b465108a0c43288654e4aa2e2013e8b)
* [Trailing newlines are no longer omitted from the diff view](https://github.com/ooyala/barkeep/issues/64)
* Nice tooltips for certain items on the page
* [Stats page style overhauled to be more consistent with saved search view](https://github.com/ooyala/barkeep/commit/1d3a23da9af5d4f1366bfb5042d77501ff1b51fe)
* [There is a checkmark indicator in the saved search view that shows which commits have been approved](https://github.com/ooyala/barkeep/issues/67)
* [The diff parser now correctly handles single line changes](https://github.com/ooyala/barkeep/issues/64)
* [Line numbers are now unselectable](https://github.com/ooyala/barkeep/commit/3e81c5634fada33b51e4289b0a12ba4255c4ef4f)
* [Switched to our own custom syntax theme, and dropped in multiple themes to allow for user-selected swapping in the future](https://github.com/ooyala/barkeep/commit/f683134ca6674efe9bc33e1e7488393c596520dd)
* [Fixed bug where added and deleted commit comments were not reflected in the UI](https://github.com/ooyala/barkeep/issues/56)
* Fixes for Google openid failures
* Comment emails now explain why the recipients are receiving mail
* Many page and code style tweaks and fixes

0.1.0
-----

### Major features

* [Emails notifications for comments are now sent to people who have saved searches that cover the commit](https://github.com/ooyala/barkeep/issues/7)
* [There is now a time range filter that applies to all saved searches](https://github.com/ooyala/barkeep/issues/12)
* [There is a 'show unapproved only' checkbox to filter each saved search](https://github.com/ooyala/barkeep/issues/8)
* [Each chunk of code (a change plus context) in the diff view is now separated by a break indicator](https://github.com/ooyala/barkeep/issues/42)
* [We now display a line at 110 characters to indicate line limit](https://github.com/ooyala/barkeep/issues/30)
* Secret dark feature that will be officially announced in the next release

### Minor features and bugfixes

* [Diffs with long lines now scroll instead of overflowing the view](https://github.com/ooyala/barkeep/issues/1)
* [Saved searches don't scroll left from the first page (it refreshes instead)](https://github.com/ooyala/barkeep/issues/2)
* [Fix "typing j/k in a comment box moves the selected line"](https://github.com/ooyala/barkeep/issues/3)
* [Fix email thread issues](https://github.com/ooyala/barkeep/issues/4)
* [Batching for comment emails](https://github.com/ooyala/barkeep/issues/6)
* [Retry sending an email when we get "connection if reset by peer"](https://github.com/ooyala/barkeep/issues/9)
* [Enter and 'o' open commits in a new tab](https://github.com/ooyala/barkeep/issues/11)
* [Fixed bug with fenced code blocks causing nested comment forms](https://github.com/ooyala/barkeep/issues/16)
* [Fixed bug where the page number doesn't change](https://github.com/ooyala/barkeep/issues/17)
* [Fixed bug where searching with branches:all returns no results](https://github.com/ooyala/barkeep/issues/19)
* [Added 'r' shortcut to refresh saved searches](https://github.com/ooyala/barkeep/commit/e1ec4a241e6b04628a8cd1d02278687ae0fe4593)
* [Added /statusz route to report deploy-time information](https://github.com/ooyala/barkeep/commit/c5cfedaf1bb00d6930260fabc339b9ef604dcfd8)
* Hundreds of styling tweaks
* Added some tests
* Code style fixes
* Much, much more
