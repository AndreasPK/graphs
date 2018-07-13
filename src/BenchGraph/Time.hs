module BenchGraph.Time (
  benchmark,
  allBench,
  benchmarkCreation
) where

import Criterion.Main
import Criterion.Types (Benchmark (..))

import Control.DeepSeq (NFData, ($!!))

import BenchGraph.GenericGraph
import BenchGraph.Utils (graphs)
import BenchGraph.Named
import BenchGraph.Types

---- Criterion
-- | Main function, will benchmark the given suite against the given graphs

benchmark :: (GraphImpl g, NFData g)
          => Bool -- ^ Set to False, it will force the graph, using deepseq, before passing it to the benched function
          -> [(GenericGraph, [Size])] -> Suite g -> Benchmark
benchmark benchCreation graphs' (Suite sname _ algo inputs') = bgroup sname cases
  where
    cases = [ bgroup gname $ map (benchSuite benchCreation (Left algo) inputs' gfunc) ss | ((gname,gfunc), ss) <- graphs' ]

benchSuite :: (GraphImpl g, NFData g, NFData o)
           => Bool -> Either (i -> g -> o) (i -> g -> IO o) -> (Edges -> [Named i]) -> (Size -> (Edges,Int)) -> Size -> Benchmark
benchSuite benchCreation algorithm' inputs' gfunc size = bgroup (show sizeName) cases
  where
    (edges, sizeName) = gfunc size
    !graph = case edges of
              [] -> const mkVertex
              _ -> mkGraph
    cases = case algorithm' of
              Left al -> if benchCreation
                then [ bench name' $ nf (al i . graph) edges | (name',i) <- inputs' edges ]
                else [ bench name' $ nf (al i) $!! graph edges | (name',i) <- inputs' edges ]
              Right al -> [ bench name' $ nfIO (al i $ graph edges) | (name',i) <- inputs' edges ]

allBench :: (GraphImpl g, NFData g)
         => Bool -- ^ Do we bench creation of the graph ?
         -> Bool -- ^ Do we use only bigger graphs ?
         -> [(String,Int)] -> Suite g -> Benchmark
allBench benchCreation b gr = benchmark benchCreation (graphs b gr)

benchmarkCreation :: (NFData g) => Bool -> [(String,Int)] -> (Edges -> g) -> Benchmark
benchmarkCreation b gr mk = bgroup "creation" [ bgroup n $ map (\i -> let (gr',sizeName) = grf i in bgroup (show sizeName) [bench "" $ nf mk gr'] ) ss | ((n,grf), ss) <- graphs b gr ]

