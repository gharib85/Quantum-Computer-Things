import qualified Data.Graph as Graph
import Data.Maybe
import qualified Data.List as DL

-- inversions are where i<j but upon the permutation pi pi(i)>pi(j) for permutations of 1..n with the standard ordering
-- 			here we output the pair (piI,piJ)
inversions :: [Int] -> [(Int,Int)]
inversions pi = [(piI,piJ) |(i,piI) <- withIndex,(j,piJ) <- withIndex, i<j, piI > piJ] where withIndex = zip [1..] pi
-- descents are for i,i+1 but pi(i)>pi(i+1), here we output the associated i
descents :: [Int] -> [Int]
descents pi = [i | ((i,piI),(j,piJ)) <- paired, piI>piJ ] where paired = zip (zip [1..] pi) $ tail (zip [1..] pi)
-- the major index adds up all the descents
majorIndex :: [Int] -> Int
majorIndex pi = sum (descents pi)
-- the inv statistic counts how many inversions there are
lengthSymmetricGroup :: [Int] -> Int
lengthSymmetricGroup pi = length $ inversions pi
-- maj and inv are equidistributed so for the same n, majStats n and invStats n will be the same as distributions
-- 			they will be permuted from each other
--			Thm: Mahonian
majStats :: Int -> [Int]
majStats n = map majorIndex (DL.permutations [1..n])
invStats :: Int -> [Int]
invStats n = map lengthSymmetricGroup (DL.permutations [1..n])

-- the example from the paper
data CoxGens = S0 | S1 | S2 | S3 deriving (Show,Read,Eq,Enum,Bounded)

myMij :: CoxGens -> CoxGens -> Maybe Int
myMij S0 S1 = Just 3
myMij S1 S0 = Just 3
myMij S1 S2 = Just 3
myMij S1 S3 = Just 3
myMij S2 S1 = Just 3
myMij S2 S3 = Just 3
myMij S3 S1 = Just 3
myMij S3 S2 = Just 3
myMij gen1 gen2
               | (gen1 == gen2) = Just 1
               | otherwise = Just 2

allGens = [(minBound::CoxGens) ..]

--parseGen :: Parser CoxGens
--parseGen = fmap read . foldr1 (<|>) $ map (try . string . show) [ (minBound :: CoxGens) ..] 

-- take a word and give the segments for repeated letters
-- for example, ABCBA will give [(0,4),(1,3)]
toTest :: [CoxGens] -> CoxGens -> [(Int,Int)]
toTest xs z = [(i,j) | (i,j) <- zip is (tail is)] where is = [i | (i, j) <- zip [0..] xs, j==z]

-- segment of word between j1 and j2 inclusive
splitWord :: [CoxGens] -> (Int,Int) -> [CoxGens]
splitWord xs (j1,j2) = [x | (i,x) <- zip [0..] xs , i>=j1 , i<=j2 ]

-- split word into 3 pieces before j1, in between and after j2
splitWord2 :: [CoxGens] -> (Int,Int) -> ([CoxGens],[CoxGens],[CoxGens])
splitWord2 xs (j1,j2) = ([x | (i,x) <- zipped , i<j1],[x | (i,x) <- zipped , i>=j1 , i<=j2 ],[x | (i,x) <- zipped , i>j2 ] ) where zipped = zip [0..] xs

-- neighbors in the coxeter graph. Uses Maybe to account for the fact that might be infinite
neighbors :: CoxGens -> (CoxGens -> CoxGens -> Maybe Int) -> [CoxGens]
neighbors x mij = [y | y <- allGens , (isNothing $ (mij x y)) || ((fromJust $ (mij x y)) > 2)]

-- given a segment xs and the letter to be tested z, check if xs has all the neighbors of z
containsAllNeighbors :: [CoxGens] -> CoxGens -> (CoxGens -> CoxGens -> Maybe Int) -> Bool
containsAllNeighbors xs z mij = and [elem y xs | y <- neighbors z mij]

-- take a word in the coxeter generators and the function encoding m_ij and give
-- the indices of a potentially reducible subword
interveningNeighbors :: [CoxGens] -> (CoxGens -> CoxGens -> Maybe Int) -> [(Int,Int)]
interveningNeighbors xs mij = concat [[ij | ij <- toTest xs z, not $ containsAllNeighbors (splitWord xs ij) z mij] | z <- allGens]

-- each of these will fail to have all their neighbors
offendingSubwords :: [CoxGens] -> (CoxGens -> CoxGens -> Maybe Int) -> [[CoxGens]]
offendingSubwords xs mij = [splitWord xs ij | ij <- interveningNeighbors xs mij]

--takes the first offending subword it finds and breaks the word into prefix, potentially reducible word and suffix
-- need a seperate algorithm to reduce the middle word
-- this then gets put back together and the cycle repeats
splitAtOffending :: [CoxGens] -> (CoxGens -> CoxGens -> Maybe Int) -> ([CoxGens],[CoxGens],[CoxGens])
splitAtOffending xs mij = splitWord2 xs (head $ interveningNeighbors xs mij)

--should say the subword s1,s0,s2,s1 is offending because there is no s3 intervening
-- that indicates should pay further attention to that word because it might be reducible
example = offendingSubwords [S0,S1,S0,S2,S1] myMij