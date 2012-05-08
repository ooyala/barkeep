## Overview

Barkeep is a fast, fun way to review code. Engineering organizations can use it to keep the bar high.

To see a video of Barkeep in action, visit [getbarkeep.org](http://getbarkeep.org).

### Getting started

Since Barkeep is a web app with dependencies like MySQL, Redis, and others, the easiest way to get it
running quickly is to run it inside a virtual machine using Vagrant:

    $ cd barkeep
    $ script/vagrant_quick_start.rb

You need a few dependencies (like VirtualBox) before you can set up Barkeep inside of Vagrant, but this script
will help you get them. It will take a few minutes and once it's done, Barkeep will be running inside of
Vagrant. You can then browse to **http://localhost:8080** to play with it.

You can shut it all down later using `bundle exec vagrant halt`.

### Documentation

**See [the wiki](https://github.com/ooyala/barkeep/wiki)** for instructions on deploying Barkeep to your own
server and for developer docs.

### Credits

Barkeep was written by the following Ooyala engineers:

* Bo Chen ([bo-chen](https://github.com/bo-chen))
* Phil Crosby ([philc](https://github.com/philc))
* Kevin Le ([bkad](https://github.com/bkad))
* Daniel MacDougall ([dmacdougall](https://github.com/dmacdougall))
* Caleb Spare ([cespare](https://github.com/cespare))

and with contributions from:

* [Noah Gibbs](mailto:noah@ooyala.com)
* Brian Zhou ([zdyn](https://github.com/zdyn))
* Manish Khettry ([mkhettry](https://github.com/mkhettry))

Barkeep is released under [the MIT license](http://www.opensource.org/licenses/mit-license.php).
