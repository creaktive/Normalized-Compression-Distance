# Normalized Compression Distance

## What is NCD?

*Normalized Compression Distance (NCD)* is actually a family of functions which
take as arguments two objects (literal files, Google search terms) and evaluate
a fixed formula expressed in terms of the compressed versions of these objects,
separately and combined. Hence this family of functions is parametrized by the
compressor used. If *x* and *y* are the two objects concerned, and *C(x)* is the
length of the compressed version of *x* using compressor *C*, then the

![NCD formula](https://complearn.org/images/ncd.gif)

The method is the outcome of a mathematical theoretical developments based on
[Kolmogorov complexity](https://en.wikipedia.org/wiki/Kolmogorov_complexity).

## References
 - [Official page of NCD](https://complearn.org/ncd.html)
