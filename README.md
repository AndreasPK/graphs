# bench-graph

## Warning: Under Active Developement
This is beign developed for the Google Summer of Code 2018.
Please do not except anything from the code for now. 

Feel free to open an issue anyway :)

## Results
Current result of `cabal bench compare` can be found here: https://travis-ci.org/haskell-perf/graphs

## Usage
You can call benchmarks with:
```Bash
$ cabal bench
```

The comparing tool can be used with:
```Bash
$ cabal bench compare
```

And you can select one function comparison with:
```Bash
$ cabal bench compare --benchmark-option=Name
```

