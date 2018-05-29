{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE TupleSections #-}

module BenchGraph (
  Suite (..),
  NSuite,
  simpleSuite,
  withNames,
  GraphImpl,
  mkGraph,
  benchmark,
  weigh,
  allBenchs,
  allWeighs,
  benchmarkCreation,
  weighCreation,
  weighCreationList,
  computeSize
) where

import Criterion.Main
import Criterion.Types (Benchmark (..))
import Weigh
import GHC.DataSize

import Control.DeepSeq (NFData, ($!!))
import Control.Monad (when)

import BenchGraph.GenericGraph
import BenchGraph.Utils (graphs, defaultGr)
import BenchGraph.Named

-- A graph algorithm operates on a graph type @g@, which takes an input of
-- type @i@ and produces an output of type @o@. Algorithms come with a list of
-- named inputs, all of which will be tried during benchmarking.
data Suite g = forall i o. NFData o => Suite
    { algorithm :: i -> g -> o
    , inputs    :: Edges -> [Named i] }

type NSuite g = Named (Suite g)

-- Not the best name, but still better than "consumer", since all algorithms
-- are consumers.
simpleSuite :: NFData o => Name -> (g -> o) -> NSuite g
simpleSuite name algorithm = (name,Suite (const algorithm) (const [("",())]))

-- Show items in a list
withNames :: Show a => [a] -> [Named a]
withNames = map nameShow

-- An interface between our generic graphs and others
class GraphImpl g where
    mkGraph :: Edges -> g

---- Criterion
benchmark :: (GraphImpl g, NFData g) => [(GenericGraph, [Size])] -> NSuite g -> Benchmark
benchmark graphs (sname,Suite algo inputs) = bgroup sname cases
  where
    cases = [ bgroup gname $ map (benchSuite algo inputs gfunc) ss | ((gname,gfunc), ss) <- graphs ]

benchSuite :: (GraphImpl g, NFData g, NFData o)
           => (i -> g -> o) -> (Edges -> [Named i]) -> (Size -> Edges) -> Size -> Benchmark
benchSuite algorithm inputs gfunc size = bgroup (show size) cases
  where
    edges = gfunc size
    graph = mkGraph edges
    cases = [ bench name $ nf (algorithm i) $!! graph | (name,i) <- inputs edges ]

allBenchs :: (GraphImpl g, NFData g) => [(String,Int)] -> [NSuite g] -> [Benchmark]
allBenchs gr = map (benchmark $ graphs gr)

benchmarkCreation :: (NFData g) => [(String,Int)] -> (Edges -> g) -> [Benchmark]
benchmarkCreation gr mk = [ bgroup ("make a " ++  n ++ " from a list") $ map (\i -> bench (show i) $ nf mk $ grf i ) ss | ((n,grf), ss) <- graphs gr ]

---- Weigh
weigh :: (GraphImpl g, NFData g) => [(GenericGraph, [Size])] -> NSuite g -> Weigh ()
weigh graphs (sname,Suite algo inputs) = wgroup sname cases
  where
    cases = mapM_ (uncurry mkGroup) graphs
    mkGroup (gname, gfunc) ss = wgroup gname $ mapM_ (weighSuite algo inputs gfunc) ss

weighSuite :: (GraphImpl g, NFData g, NFData o)
           => (i -> g -> o) -> (Edges -> [Named i]) -> (Size -> Edges) -> Size -> Weigh ()
weighSuite algorithm inputs gfunc size = wgroup (show size) cases
  where
    edges = gfunc size
    graph = mkGraph edges
    cases = mapM_ (uncurry wFunc) $ inputs edges
    wFunc name i = func name (algorithm i) $!! graph

allWeighs :: (GraphImpl g, NFData g) => [NSuite g] -> Weigh ()
allWeighs = mapM_ (weigh $ graphs defaultGr)

-- | Use the list from weighCreationList
weighCreation :: (NFData g)
              => Maybe String -- ^ Maybe a selected bench to do
              -> (Edges -> g) -- ^ A graph-creator function, typically from the GraphImpl class
              -> Weigh ()
weighCreation name mk = sequence_ [when (todo str) $ wgroup str $ mapM_ (\i -> func (show i) mk $ grf i ) ss | (str,((n,grf), ss)) <- weighCreationList ]
  where
    todo str  = maybe True (str ==) name

-- | List of generic graph with their case-name
weighCreationList :: [Named (GenericGraph, [Int])]
weighCreationList = [ (str n,t) | t@((n, _), _) <- graphs defaultGr]
  where
    str n = "make a " ++ n ++ " from a list"

---- DataSize

computeSize :: (NFData g) => [(String,Int)] -> (Edges -> g) -> IO [Named [Named Word]]
computeSize gr fun = mapM (\((gname, gfunc),ss) -> sequence $ (gname,) $ mapM (\s -> sequence $ (show s,) $ recursiveSize $!! fun $ gfunc s) ss) $ graphs gr

