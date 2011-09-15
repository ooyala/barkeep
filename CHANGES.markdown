Barkeep Changes
===============

This file summarizes changes between tagged Barkeep versions. It lists tags in reverse chronological order.
Each tag is followed by a description of the changes it represents. This is not in a typical Changelog format,
but rather general markdown text describing important notes about the versions and progress of Barkeep.

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
