Styles in here were generated from vim and pygments themes of the same name. I used
[vim2pygments](https://github.com/honza/vim2pygments) and the the process described
[here](http://honza.ca/2011/02/how-to-convert-vim-colorschemes-to-pygments-themes) to convert these to css
files, and then ran the files through the following filters (note that `$` marks the beginning of commands,
and `>` marks contined lines):

    $ sed -i "" 's/^\.highlight *//g' *.css
    $ sed -i "" '/^{/d' *.css
    $ for file in *.css; do sed -i "" '1i\
    > .code, .commentCode {
    > ' $file; done
    $ for file in *.css; do sed -i "" '$a\
    > }' $file; done
    $ for f in *.css; do mv ${f/%.css/.scss}; done

I tried this with a bunch of files initially, and threw out the really terrible themes. In my opinion, the
best ones are:

* autumn
* default
* pastie
* trac

Also bw is a pretty nice black-and-white only theme.

-Caleb
