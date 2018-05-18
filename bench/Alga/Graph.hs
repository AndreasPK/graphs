{-# OPTIONS_GHC -fno-warn-orphans #-}
{-# LANGUAGE FlexibleInstances #-}

module Alga.Graph
  (functions, mk)
where

import BenchGraph
import BenchGraph.Suites
import BenchGraph.GenericGraph (Edges)

import Algebra.Graph

instance GraphImpl (Graph Int) where
  mkGraph = edges

mk :: Edges -> Graph Int
mk = edges

functions :: [Suite (Graph Int)]
functions =
  [ isEmptyS isEmpty
  , vertexListS vertexList
  , edgeListS edgeList
  , hasEdgeS (uncurry hasEdge) id
  , addVertexS connect vertex
  , removeVertexS removeVertex id
  , eqS (==)
  , removeEdgeS (uncurry removeEdge) id
  ]

