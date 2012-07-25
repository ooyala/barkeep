## Overview

Barkeep is a fast, fun way to review code. Engineering organizations can use it to keep the bar high.

To see a video of Barkeep in action, visit [getbarkeep.org](http://getbarkeep.org).

Barkeep is standalone software that you host. Once it's set up, you can use it to track and code review any
number of git repos available on the internet. It's designed to be easy to run on Ubuntu.

### Getting started

Since Barkeep is a web app with dependencies like MySQL, Redis, and others, the easiest way to get it
running quickly is to run it inside a virtual machine using Vagrant:

    $ cd barkeep
    $ script/vagrant_quick_start.rb

You will need a few dependencies (like VirtualBox) before you can set up Barkeep inside of Vagrant, but this
script will help you get them. It will take a few minutes and once it's done, Barkeep will be running inside
of Vagrant. You can then browse to **http://localhost:8080** to play with it.

You can shut it all down later using `bundle exec vagrant halt`.

Once you decide to use Barkeep for your team, you should deploy it to an Ubuntu web server. See the [Deploying
Barkeep](https://github.com/ooyala/barkeep/wiki/Deploying-Barkeep) wiki page for more information.

### Docs

See **[the wiki](https://github.com/ooyala/barkeep/wiki)** for instructions on setting up Barkeep for
development, deploying it to your own server and tracking git repos with it.

[Read here](https://github.com/ooyala/barkeep/wiki/Comparing-Barkeep-to-other-code-review-tools) for a
comparison of Barkeep to other code review systems.

### Contributing

Barkeep was designed to be easy to hack on with Mac or Ubuntu, so feel free to dive in. Open a ticket to
suggest a new feature or just send a pull request with your changes.

Simple style guidelines: mimic the style around you, cap lines at 110 characters.

### Credits

Barkeep was written by the following Ooyala engineers:

* Bo Chen ([bo-chen](https://github.com/bo-chen))
* Phil Crosby ([philc](https://github.com/philc))
* Kevin Le ([bkad](https://github.com/bkad))
* Daniel MacDougall ([dmacdougall](https://github.com/dmacdougall))
* Caleb Spare ([cespare](https://github.com/cespare))

and with contributions from other Ooyala engineers:

* Noah Gibbs ([noahgibbs](https://github.com/noahgibbs))
* Brian Zhou ([zdyn](https://github.com/zdyn))
* Manish Khettry ([mkhettry](https://github.com/mkhettry))

and community members:

* Alberto Leal ([albertoleal](https://github.com/albertoleal))
* Alice Kærast ([kaerast](https://github.com/kaerast))
* Dann Luciano ([dannluciano](https://github.com/dannluciano))
* Michael Quinn ([mikejquinn](https://github.com/mikejquinn))

Barkeep is released under [the MIT license](http://www.opensource.org/licenses/mit-license.php).
