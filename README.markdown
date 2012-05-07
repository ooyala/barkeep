## Overview

Barkeep is a fast, fun way to review code. Engineering organizations can use it to keep the bar high.

To see a video of Barkeep in action, visit [getbarkeep.org](http://getbarkeep.org).

### Getting started

Since Barkeep is a web app with dependencies (like MySQL, Redis, and others), the easiest way to get it
running quickly is to run it inside a virtual machine using Vagrant:

     script/vagrant_quick_start.rb

That will take a few minutes. Once that's done, Barkeep will be running inside of Vagrant. You can then browse
to http://localhost:8080 to play with it.

Later you can shut it all down using `bundle exec vagrant halt`.

### Documentation

See [the wiki](https://github.com/ooyala/barkeep/wiki) for docs on everything else.

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
