relational-programming-in-miniKanren
====================================

Relational Programming in miniKanren

(or, Will was completely jet-lagged from Norway, and decided to start a book since he couldn't sleep anyway)


This work is licensed under a Creative Commons Attribution 3.0 Unported License.
(CC BY 3.0)  (http://creativecommons.org/licenses/by/3.0/)



Build instructions:

I build the book under Mac OS 10.8 using the MacTeX-2012 Distribution of TeX Live. (http://tug.org/mactex/) For some bizarre reason, you need to be careful when downloading the `MacTeX.pkg` file, or it will be corrupted; one safe way to download the file is to use Safari.  I'm typesetting the book using XeLaTeX, which should be included in any modern TeX distribution.

I'm using SLaTeX (http://www.ccs.neu.edu/home/dorai/slatex/) to typeset Scheme and miniKanren code.  I've included SLaTeX in the Github repo, but SLaTeX expects a Scheme implementation in order to work.  I'm using the 32-bit nonthreaded version of Petite Chez Scheme 8.4 (http://www.scheme.com/download/).  If you use another Scheme implementation, you'll have to update the `xeslatex` file in the main directory, replacing `petite` with your Scheme implementation of choice.  Of course you will need to make sure your Scheme implementation is on your `PATH`.

Once you have installed your TeX distribution and a Scheme implementation, you should be ready to typeset the book:

`make squeaky; make`

`make squeaky` removes all generated files, including the PDF of the book.  `make clean` removes temporary files, but not the book PDF.


TODO

* write book
* ???
* profit!
