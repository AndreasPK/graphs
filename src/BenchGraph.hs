{-# LANGUAGE ExistentialQuantification #-}

module BenchGraph (
  Suite (..),
  simpleSuite,
  withNames,
  GraphImpl,
  mkGraph,
  benchmark,
  weigh,
  allBenchs,
  allWeighs
) where

import Criterion.Main
import Weigh
import Control.DeepSeq (NFData(..), ($!!))

import BenchGraph.GenericGraph
import BenchGraph.Utils (graphs)

-- A graph algorithm operates on a graph type @g@, which takes an input of
-- type @i@ and produces an output of type @o@. Algorithms come with a list of
-- named inputs, all of which will be tried during benchmarking.
data Suite g = forall i o. NFData o => Suite
    { suiteName :: Name
    , algorithm :: i -> g -> o
    , inputs    :: Edges -> [(Name, i)] }

-- Not the best name, but still better than "consumer", since all algorithms
-- are consumers.
simpleSuite :: NFData o => Name -> (g -> o) -> Suite g
simpleSuite name algorithm = Suite name (const algorithm) (const [("", ())])

-- Show items in a list
withNames :: Show a => [a] -> [(Name, a)]
withNames = map (\x -> (show x, x))

-- An interface between our generic graphs and others
class GraphImpl g where
    mkGraph :: Edges -> g

---- Criterion

benchmark :: (GraphImpl g, NFData g) => [(GenericGraph, [Size])] -> Suite g -> Benchmark
benchmark graphs (Suite sname algo inputs) = bgroup sname cases
  where
    cases = [ bgroup (name g) $ map (benchSuite algo inputs g) ss | (g, ss) <- graphs ]

benchSuite :: (GraphImpl g, NFData g, NFData o)
    => (i -> g -> o) -> (Edges -> [(Name, i)]) -> GenericGraph -> Size -> Benchmark
benchSuite algorithm inputs g size = bgroup (show size) cases
  where
    edges = mk g size
    graph = mkGraph edges
    cases = [ bench name $ nf (algorithm i) $!! graph | (name, i) <- inputs edges ]

allBenchs :: (GraphImpl g, NFData g) => [Suite g] -> [Benchmark]
allBenchs = map (benchmark graphs)

---- Weigh
weigh :: (GraphImpl g, NFData g) => [(GenericGraph, [Size])] -> Suite g -> Weigh ()
weigh graphs (Suite sname algo inputs) = wgroup sname cases
  where
    cases = mapM_ (uncurry mkGroup) graphs
    mkGroup g ss = wgroup (name g) $ mapM_ (weighSuite algo inputs g) ss

weighSuite :: (GraphImpl g, NFData g, NFData o)
           => (i -> g -> o) -> (Edges -> [(Name, i)]) -> GenericGraph -> Size -> Weigh ()
weighSuite algorithm inputs g size = wgroup (show size) cases
  where
    edges = mk g size
    graph = mkGraph edges
    cases = mapM_ (uncurry wFunc) $ inputs edges
    wFunc name i = func name (algorithm i) $!! graph

allWeighs :: (GraphImpl g, NFData g) =>  [Suite g] -> Weigh ()
allWeighs = mapM_ (weigh graphs)
