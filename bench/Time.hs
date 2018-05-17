import Data.List (filter, nub, sort)
import Data.Maybe (mapMaybe, isNothing, isJust)
import Control.Monad (unless, when, (>=>))

import Criterion
import Criterion.Types
import Criterion.Internal
import Criterion.Main.Options (defaultConfig)
import Criterion.Measurement (initializeTime)
import Criterion.Monad (withConfig)

import Statistics.Types

import qualified Alga.Graph
import qualified Containers.Graph
import qualified Fgl.PatriciaTree
import qualified HashGraph.Gr

import BenchGraph (allBenchs)
import BenchGraph.Named

import Control.Comonad (extract)

import Options.Applicative (execParser)

import Command
import Types
import Best

import qualified Text.Tabular as T
import qualified Text.Tabular.AsciiArt as TAA

-- We consider Benchmark equality using their name
instance Eq Benchmark where
  a == b = showBenchName a == showBenchName b

showBenchName :: Benchmark -> Name
showBenchName (Benchmark n _) = n
showBenchName (BenchGroup n _) = n

genReport :: Int
           -- ^ The number of '#' to write
           -> Maybe Flag
           -- ^ Flag ?
           -> [Named Benchmark]
           -- ^ The list of benchmarks with their library name
           -> IO()
genReport _ _ [] = putStrLn "\nNo data\n"
genReport lev flg arr = mapM_ (toPrint lev flg arr . extract >=> printBest "was the fastest") $ nub arr

toPrint :: Int -> Maybe Flag -> [Named Benchmark] -> Benchmark -> IO (Grouped [Named Double])
toPrint lev flg arr breport = do
  let bname = showBenchName breport
  unless (null bname || (isJust flg && lev /= 2)) $ putStrLn $ replicate lev '#' ++ " " ++ bname
  case breport of
    Benchmark{} -> do
      simples <- mapM (traverse benchmarkWithoutOutput) $ mapMaybe (traverse tkSimple) $ here breport
      when (isNothing flg) $ putStrLn $ "\n" ++ showSimples simples
      return $ Simple simples
    BenchGroup{} -> Group <$> mapM (toPrint (lev+1) flg otherGroups . extract) (nub otherGroups)
  where
    otherGroups = concatMap sequence $ mapMaybe (traverse tkChilds) $ here breport
    here e = filter (liftExtract (== e)) arr

-- | Bench only if it is possible
tkSimple :: Benchmark -> Maybe Benchmarkable
tkSimple (Benchmark _ b) = Just b
tkSimple _ = Nothing

-- | Get the childs of a BenchGroup, inserting the name of the library
tkChilds :: Benchmark -> Maybe [Benchmark]
tkChilds (BenchGroup _ childs) = Just childs
tkChilds _ = Nothing

showSimples :: [Named Double] -> String
showSimples arr = TAA.render id id id table
  where
    arrD = sort $ map (show . extract) arr
    libs = map show arr
    table = T.Table
      (T.Group T.NoLine $ map T.Header libs)
      (T.Group T.SingleLine [T.Header "Seconds (Mean)"])
      (map return arrD)

getMean :: Report -> Double
getMean = estPoint . anMean . reportAnalysis

-- | Utilitary, disable the standard output of Criterion
benchmarkWithoutOutput :: Benchmarkable -> IO Double
benchmarkWithoutOutput bm = do
  initializeTime
  withConfig defaultConfig' $ do
    Analysed rpt <- runAndAnalyseOne 0 "function" bm
    return $ getMean rpt
  where
    defaultConfig' = defaultConfig {verbosity = Quiet}

-- show a list of benchmarks
showListN :: [Named Benchmark] -> String
showListN = unlines . map (showBenchName . extract)

main :: IO ()
main = execParser commandTime >>= main'

main' :: Command -> IO ()
main' opts
  = case opts of
      List -> putStr $ showListN grList'
      Run opt flg -> do
          let todo = case opt of
                Nothing -> grList'
                Just opt' -> case opt' of
                  Only bname -> filter ((==) bname . showBenchName . extract) grList'
                  Part one' two -> let one = one' + 1
                                       per = length grList' `div` two
                                   in drop ((one-1)*per) $ take (one*per) grList'
          let samples = filter (`elem` todo) grList
          putStrLn "# Compare benchmarks\n"
          putStrLn "Doing:"
          putStrLn $ "\n----\n"++ showListN todo ++ "----\n"
          genReport 2 flg samples

  where
    grList = concatMap (sequence . toNamed) [
     ("Alga (Algebra.Graph)",allBenchs Alga.Graph.functions),
     ("Containers (Data.Graph)",allBenchs Containers.Graph.functions),
     ("Fgl (Data.Graph.Inductive.PatriciaTree)", allBenchs Fgl.PatriciaTree.functions),
     ("Hash-Graph (Data.HashGraph.Strict)", allBenchs HashGraph.Gr.functions)]
    grList' = nub grList
