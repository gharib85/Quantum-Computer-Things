{-# LANGUAGE GADTs #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE DataKinds, TypeFamilies, TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}

import qualified Data.List as L
import qualified Math.Combinatorics.Poset as PS
import qualified Math.Combinat.Partitions.Set as SetPart
import qualified Data.Set as Set
import qualified Math.Combinatorics.Digraph as DG
import qualified Control.Exception as E
import Data.Maybe

data Nat = Z | S Nat deriving (Show)

infixl 6 :+
infixl 7 :*

type family   (n :: Nat) :+ (m :: Nat) :: Nat
type instance Z     :+ m = m
type instance (S n) :+ m = S (n :+ m)

type family   (n :: Nat) :* (m :: Nat) :: Nat
type instance Z     :* m = Z
type instance (S n) :* m = (n :* m) :+ m

data Vector a n where
  Nil  :: Vector a Z
  (:-) :: a -> Vector a n -> Vector a (S n)
infixr 5 :-

deriving instance Eq a => Eq (Vector a n)

toList :: Vector a n -> [a]
toList Nil = []
toList (x :- xs) = x : toList xs

instance Show a => Show (Vector a n) where
  showsPrec d = showsPrec d . toList

{- --didn't end up needing these so commented out
data SNat n where
  SZ :: SNat Z
  SS :: SNat n -> SNat (S n)

-- make a vector of length n filled with same things
replicate :: SNat n -> a -> Vector a n
replicate SZ     _ = Nil
replicate (SS n) a = a :- replicate n a

--takes a natural number n and a list of integers and puts them into a vector of length n
-- default to -1 if the list is too short
fromList:: SNat n -> [Int] -> Vector Int n
fromList SZ _ = Nil
fromList (SS n) [] = replicate (SS n) (-1)
fromList (SS n) (x:xs) = x :- (fromList n xs)
-}

data ErrorCorrectionFlags = Steane | BitFlip | SignFlip | Shor deriving (Read,Eq,Show)

data ECCScheme = None | S1 ECCScheme | S2 ECCScheme | S3 ECCScheme | S4 ECCScheme deriving (Show)

{-Internal indices stores the index for the qubit with the error correction scheme. This is done by
If there is no error correction then it is Lgcl a to say it's the a'th logical qubit.
If applied a Steane code then see Int1 a (rest) which means it is a is the index within the Steane code and rest is the index before
Same with the rest of the ErrorCorrectionFlags. Compose them as long as desired
-}
data InternalIndices a n where
  Lgcl  :: a -> InternalIndices a None
  Int1 :: a -> InternalIndices a n -> InternalIndices a (S1 n)
  Int2 :: a -> InternalIndices a n -> InternalIndices a (S2 n)
  Int3 :: a -> InternalIndices a n -> InternalIndices a (S3 n)
  Int4 :: a -> InternalIndices a n -> InternalIndices a (S4 n)

deriving instance Eq a => Eq (InternalIndices a n)

toList2 :: InternalIndices a n -> [a]
toList2 (Lgcl x) = [x]
toList2 (Int1 x xs) = x : toList2 xs
toList2 (Int2 x xs) = x : toList2 xs
toList2 (Int3 x xs) = x : toList2 xs
toList2 (Int4 x xs) = x : toList2 xs

instance Show a => Show (InternalIndices a n) where
  showsPrec d = showsPrec d . toList2

-- occupation
data ECCSchemeCopy n where
  NoneCopy :: ECCSchemeCopy None
  S1Copy :: ECCSchemeCopy n -> ECCSchemeCopy (S1 n)
  S2Copy :: ECCSchemeCopy n -> ECCSchemeCopy (S2 n)
  S3Copy :: ECCSchemeCopy n -> ECCSchemeCopy (S3 n)
  S4Copy :: ECCSchemeCopy n -> ECCSchemeCopy (S4 n)

-- puts the same x in all the internal indices for each stage of ECCSchemeCopy n
myreplicate :: ECCSchemeCopy n -> a -> InternalIndices a n
myreplicate NoneCopy x = (Lgcl x)
myreplicate (S1Copy n) x = Int1 x (myreplicate n x)
myreplicate (S2Copy n) x = Int2 x (myreplicate n x)
myreplicate (S3Copy n) x = Int3 x (myreplicate n x)
myreplicate (S4Copy n) x = Int4 x (myreplicate n x)

codeLengths::ErrorCorrectionFlags -> Int
codeLengths Steane = 7
codeLengths BitFlip = 3
codeLengths SignFlip = 3
codeLengths Shor = 9

myMod:: Int -> Int -> Int
myMod x y = x `mod` y

-- takes a vector of integers of length n for the internal indices at each stage and the flags at each stage
-- reduces them all to make sure they are within the appropriate bounds
-- for example if we see (4,5,6) with flags (SignFlip,Shor,Steane) we would know this took one logical qubit looked at the 6th upon applying a Steane code
-- then the 5th of a Shor code then the 1st=4th of a SignFlip code
reduceGateIndices:: (Vector Int n) -> (Vector ErrorCorrectionFlags n) -> [Int]
reduceGateIndices x y = zipWith myMod (toList x) allCodeLengths where allCodeLengths=map codeLengths $ toList y

-- similar to above but with (InternalIndices Int n) format instead of vector and list format
reduceGateIndices2:: InternalIndices Int n -> InternalIndices Int n
reduceGateIndices2 (Lgcl x) = Lgcl x
reduceGateIndices2 (Int1 x xs) = Int1 (x `mod` (codeLengths Steane)) (reduceGateIndices2 xs)
reduceGateIndices2 (Int2 x xs) = Int2 (x `mod` (codeLengths BitFlip)) (reduceGateIndices2 xs)
reduceGateIndices2 (Int3 x xs) = Int3 (x `mod` (codeLengths SignFlip)) (reduceGateIndices2 xs)
reduceGateIndices2 (Int4 x xs) = Int4 (x `mod` (codeLengths Shor)) (reduceGateIndices2 xs)

-- also say there is a fixed number z of logical qubits
reduceGateIndices3:: Int -> InternalIndices Int n -> InternalIndices Int n
reduceGateIndices3 z (Lgcl x) = Lgcl (x `mod` z)
reduceGateIndices3 z (Int1 x xs) = Int1 (x `mod` (codeLengths Steane)) (reduceGateIndices3 z xs)
reduceGateIndices3 z (Int2 x xs) = Int2 (x `mod` (codeLengths BitFlip)) (reduceGateIndices3 z xs)
reduceGateIndices3 z (Int3 x xs) = Int3 (x `mod` (codeLengths SignFlip)) (reduceGateIndices3 z xs)
reduceGateIndices3 z (Int4 x xs) = Int4 (x `mod` (codeLengths Shor)) (reduceGateIndices3 z xs)

data ParameterizedRZ1 = ParameterizedRZ1{rotation_angle::Float} deriving (Read,Show,Eq)
data ParameterizedRFull1 = ParameterizedRFull1{alpha::Float,beta::Float,theta::Float} deriving (Read,Show,Eq)
promote :: ParameterizedRZ1 -> ParameterizedRFull1
promote rzgate = ParameterizedRFull1{alpha=0,beta=0,theta=(rotation_angle rzgate)}
newtype ParameterizedGateNames = ParameterizedGateNames{my_param_gate::Either ParameterizedRZ1 ParameterizedRFull1}

data GateNames = PauliX1 | PauliY1 | PauliZ1 | Hadamard1 | QuarterPhase1 | SqrtSwap2 | CNOT2 | Swap2 | Tof3 deriving (Read, Show, Eq)

newtype GateNamesWithParams = GateDataWithParams{my_name::Either GateNames ParameterizedGateNames}

-- how many qubits does this kind of gate operate on
arity::GateNames -> Int
arity PauliX1 = 1
arity PauliY1 = 1
arity PauliZ1 = 1
arity Hadamard1 = 1
arity QuarterPhase1 = 1
arity SqrtSwap2 = 2
arity CNOT2 = 2
arity Swap2 = 2
arity Tof3 = 3

arity_param :: ParameterizedGateNames -> Int
arity_param _ = 1

arity_combined :: GateNamesWithParams -> Int
arity_combined x = either arity arity_param (my_name x)

-- A gate is given as a name and a list of involved qubits
data GateData n = GateData{name::GateNames, myinvolvedQubits::[InternalIndices Int n]} deriving (Eq,Show)

-- how many qubits does this actual gate operate on
arity2:: GateData n -> Int
arity2 x = arity (name x)

allDifferent :: (Eq a) => [a] -> Bool
allDifferent []     = True
allDifferent (x:xs) = x `notElem` xs && allDifferent xs

--check that the arity matches the number of qubits operated on. Then makes sure that the two are distinct if supposed to operate on 2
checkValidGate::GateData n -> Bool
checkValidGate x = (((( length qubits)) == (arity2 x)) && (allDifferent qubits)) where qubits = (map reduceGateIndices2 (myinvolvedQubits x))

validateGate :: GateData n -> GateData n
validateGate x
                | (checkValidGate x) = GateData {name=myName,myinvolvedQubits=(map reduceGateIndices2 myInv)}
                | otherwise = error $ "Invalid Gate"++(show x)
                 where { myName=(name x) ; myInv = (myinvolvedQubits x)}

validateCircuit :: [GateData n] -> [GateData n]
validateCircuit xs = map validateGate xs

-- assuming g1 and g2 are valid gates check if they commute in the simplest way which is they have disjoint supports
definitelyCommute:: GateData n -> GateData n -> Bool
definitelyCommute x y
    | inCommon==[] = True
    | otherwise = (x == y)
    where inCommon=(map reduceGateIndices2 (myinvolvedQubits x)) `L.intersect` (map reduceGateIndices2 (myinvolvedQubits y))


-- invert circuits by concatenating the inverses of basic gates
inverseGate :: GateData n -> [GateData n]
inverseGate GateData{name=PauliX1,myinvolvedQubits=y} = [GateData{name=PauliX1,myinvolvedQubits=y}]
inverseGate GateData{name=PauliY1,myinvolvedQubits=y} = [GateData{name=PauliY1,myinvolvedQubits=y}]
inverseGate GateData{name=PauliZ1,myinvolvedQubits=y} = [GateData{name=PauliZ1,myinvolvedQubits=y}]
inverseGate GateData{name=Hadamard1,myinvolvedQubits=y} = [GateData{name=Hadamard1,myinvolvedQubits=y}]
inverseGate GateData{name=QuarterPhase1,myinvolvedQubits=y} = [GateData{name=QuarterPhase1,myinvolvedQubits=y},GateData{name=QuarterPhase1,myinvolvedQubits=y},GateData{name=QuarterPhase1,myinvolvedQubits=y}]
inverseGate GateData{name=SqrtSwap2,myinvolvedQubits=y} = [GateData{name=SqrtSwap2,myinvolvedQubits=y},GateData{name=SqrtSwap2,myinvolvedQubits=y},GateData{name=SqrtSwap2,myinvolvedQubits=y}]
inverseGate GateData{name=CNOT2,myinvolvedQubits=y} = [GateData{name=CNOT2,myinvolvedQubits=y}]
inverseGate GateData{name=Swap2,myinvolvedQubits=y} = [GateData{name=Swap2,myinvolvedQubits=y}]
inverseGate GateData{name=Tof3,myinvolvedQubits=y} = [GateData{name=Tof3,myinvolvedQubits=y}]

inverseCircuit :: [GateData n] -> [GateData n]
inverseCircuit [] = []
inverseCircuit (x:xs) = (inverseCircuit xs) ++ (inverseGate x)

--Example
circuitToInvert=[GateData{name=SqrtSwap2,myinvolvedQubits=[Lgcl 1,Lgcl 2]},GateData{name=SqrtSwap2,myinvolvedQubits=[Lgcl 3,Lgcl 2]}]
testinverseCircuit=inverseCircuit circuitToInvert

--cancel inverses in the circuit
simplifyCircuit :: [GateData n] -> [GateData n]
simplifyCircuit [] = []
simplifyCircuit (x:xs)
                       | isNothing ys = x:(simplifyCircuit xs)
                       | otherwise = fromJust ys
                       where ys=L.stripPrefix (inverseGate x) xs

simplifyCircuit2 :: [GateData n] -> [GateData n]
simplifyCircuit2 x
                   | (length y)==(length x) = y
                   | otherwise = simplifyCircuit2 y
                   where y=simplifyCircuit x

shouldBeEmpty = simplifyCircuit2 (circuitToInvert++testinverseCircuit)

--when making the computation DAG will have multiple instances of the same gate, so putting an extra integer in to separate everything out so none equal
newtype GateData2 n = GateData2 { myData :: (GateData n , Int)} deriving (Eq,Show)
instance Ord (GateData2 n) where (GateData2 (_,y1)) `compare` (GateData2 (_,y2)) = (y1 `compare` y2)
data Initialize = InitializeGate

-- builds up the DAG from the beginning on, by putting edges in when the gate about to add has dependence on something before
-- wrong
newes :: a -> [a] -> [(a,a)]
newes x dependence = [(v,x) | v <- dependence]
myReplace :: Eq a => [a] -> a -> [a] -> [a]
myReplace oldTop new toReplace = new:(oldTop L.\\ toReplace)
makeDAGHelper :: ([(GateData2 n, GateData2 n)],[GateData2 n]) -> GateData2 n -> ([(GateData2 n, GateData2 n)],[GateData2 n])
makeDAGHelper (es,vs) x
                       | (dependence == []) = (es,x:vs)
                       | otherwise = (es++(newes x dependence), myReplace vs x dependence)
                       where dependence = [v | v <- vs, not $ definitelyCommute (fst $ myData x) (fst $ myData v) ]

makeDAGHelper2 :: [GateData2 n] -> ([(GateData2 n, GateData2 n)],[GateData2 n])
makeDAGHelper2 circuit = foldl makeDAGHelper ([],[]) circuit

makeDAG :: [GateData2 n] -> DG.Digraph (GateData2 n)
makeDAG circuit = DG.DG circuit (fst $ makeDAGHelper2 circuit)

-- DAG to poset
makeDAG2 :: [GateData n] -> PS.Poset (GateData2 n)
makeDAG2 circuit = PS.reachabilityPoset $ makeDAG (map GateData2 (zip circuit [1..]))

-- |The ordinal sum of two posets
osum :: PS.Poset a -> PS.Poset b -> PS.Poset (Either a b)
osum (PS.Poset (setA,poA)) (PS.Poset (setB,poB)) = PS.Poset (set,po)
    where set = map Left setA ++ map Right setB
          po (Left a1) (Left a2) = poA a1 a2
          po (Right b1) (Right b2) = poB b1 b2
          po (Left _) (Right _) = True
          po _ _ = False

bottomPoset :: PS.Poset Initialize
bottomPoset = PS.Poset ([InitializeGate],(\x -> \y -> True))

-- makeDAG2 had multiple gates at the bottom because any one of them could show up first
-- drawing function required a unique bottom so put that in with an ordinal sum
makeDAG3 :: [GateData n] -> PS.Poset (Either Initialize (GateData2 n))
makeDAG3 circuit = osum bottomPoset (makeDAG2 circuit)

--partition Logic
compareSetPartitions :: SetPart.SetPartition -> SetPart.SetPartition -> Bool
compareSetPartitions sp1 sp2 = and [isXSubset (Set.fromList x) sp1 | x <- SetPart.fromSetPartition sp2 ] where 
                               isXSubset x1 sp1' = or [ Set.isSubsetOf x1 (Set.fromList y) | y <- SetPart.fromSetPartition sp1' ]
partitionPoset :: Int -> PS.Poset SetPart.SetPartition
partitionPoset n = PS.Poset (SetPart.setPartitions n, compareSetPartitions)

-- a list of blocks B_i so the state is said to be in that associated Segre embedding and no refinement thereof
-- the boolean is there to say if it is pure or not. So (B_1,False),(B_2,True)
-- means a density matrix that is the form \rho_1 \otimes \rho_2 with \rho_2 being rank 1 and \rho_1 higher rank
newtype EntanglementPattern n = EntanglementPattern {myPattern :: [([(InternalIndices Int n)],Bool)]} deriving (Eq,Show)

anyxsInside :: (Eq a) => [a] -> [a] -> Bool
anyxsInside xs thisList = or [elem x thisList | x <- xs]

modifyPattern :: [InternalIndices Int n] -> EntanglementPattern n -> EntanglementPattern n
modifyPattern [] pattern = pattern
modifyPattern xs pattern = EntanglementPattern {myPattern=((allInvolved,purity):[y | y<- myPattern pattern, not $ anyxsInside xs (fst y)])}
                            where {allInvolved = concat [fst y1 | y1<- myPattern pattern, anyxsInside xs (fst y1)];
                                   purity = and [snd y2 | y2 <- myPattern pattern, anyxsInside xs (fst y2)]}

-- if the entanglement Pattern tells you there is a given set partition describing the entanglement
-- then apply a gate g acting on qubits i and j, give the new set partition that puts i and j into the same block
-- these ones keep all the boolean flags True because the entire state is still pure
-- when combining blocks the boolean flags get and'ed together
changeEntanglementPattern :: GateData n -> EntanglementPattern n -> EntanglementPattern n
changeEntanglementPattern gate pattern 
                                        | arity2 gate==1 = pattern
                                        | otherwise = modifyPattern (myinvolvedQubits gate) pattern
-- fold for an entire circuit
changeEntanglementPattern2 :: [GateData n] -> EntanglementPattern n -> EntanglementPattern n
changeEntanglementPattern2 [] startingPattern = startingPattern
changeEntanglementPattern2 (x:xs) startingPattern = changeEntanglementPattern2 xs (changeEntanglementPattern x startingPattern)
-- make the block that contains index qubitMeasured into a mixed state
-- the eigenvalues are the probabilities of the measurement. So maybe measurement is wrong word.
-- Did the operation but didn't record it so it is stuck with that leftover classical uncertainty.
measure :: InternalIndices Int n -> EntanglementPattern n -> EntanglementPattern n
measure qubitMeasured pattern = EntanglementPattern {myPattern = [(fst y,snd y && not (qubitMeasured `elem` (fst y)))| y <- myPattern pattern]}

--Sleator Winfurter construction of doubly controlled U=V^2
-- for example Toffoli gate
-- this doesn't work because CV2,CVDag2 are not valid gate names
-- simple fix, just add those to the namespace
--sleatorWinfurterExpand :: InternalIndices Int n -> InternalIndices Int n -> InternalIndices Int n -> [GateData n]
--sleatorWinfurterExpand targetQubit controlOne controlTwo = [controlVPartOne,cnotPart,controlVPartTwo,cnotPart,controlVPartThree]
--                                                where cnotPart=GateData{name=CNOT2,myinvolvedQubits=[controlOne,controlTwo]}
--												      controlVPartOne=GateData{name=CV2,myinvolvedQubits=[controlTwo,targetQubit]}
--													  controlVPartTwo=GateData{name=CVDag2,myinvolvedQubits=[controlTwo,targetQubit]}
--													  controlVPartThree=GateData{name=CV2,myinvolvedQubits=[controlOne,targetQubit]}


{-
--Steane
encodingCircuit1 :: InternalIndices Int n -> [GateData (S1 n)]
decodingCircuit1 :: InternalIndices Int n -> [GateData (S1 n)]
--BitFlip
encodingCircuit2 :: InternalIndices Int n -> [GateData (S2 n)]
encodingCircuit2 x = [GateData{name=CNOT2,myinvolvedQubits=[Int2 0 x,Int2 1 x]},GateData{name=CNOT2,myinvolvedQubits=[Int2 0 x,Int2 2 x]}]
decodingCircuit2 :: InternalIndices Int n -> [GateData (S2 n)]
--SignFlip
encodingCircuit3 :: InternalIndices Int n -> [GateData (S3 n)]
decodingCircuit3 :: InternalIndices Int n -> [GateData (S3 n)]
--Shor
encodingCircuit4 :: InternalIndices Int n -> [GateData (S4 n)]
decodingCircuit4 :: InternalIndices Int n -> [GateData (S4 n)]

-- puts a gate with same name in the 0th index of the corresponding error correction flag. This corresponds to the case when just adjoined ancillas
-- for the k-1 in each batch but not did an error correction. The gates just operate on the 0th indices.
implementECC1Helper :: GateData n -> GateData (S1 n)
implementECC1Helper x = GateData(name=(name x),myinvolvedQubits = Int1 0 (myinvolvedQubits x))
implementECC2Helper :: GateData n -> GateData (S2 n)
implementECC2Helper x = GateData(name=(name x),myinvolvedQubits = Int2 0 (myinvolvedQubits x))
implementECC3Helper :: GateData n -> GateData (S3 n)
implementECC3Helper x = GateData(name=(name x),myinvolvedQubits = Int3 0 (myinvolvedQubits x))
implementECC4Helper :: GateData n -> GateData (S4 n)
implementECC4Helper x = GateData(name=(name x),myinvolvedQubits = Int4 0 (myinvolvedQubits x))

--Take a gate with internal indices in a ECCScheme n and produces the corresponding circuit that implements the same gate but after an additional
-- error correction step. This is done by conjugation by encoding/decoding
-- Caution: the order is left to right of application
implementECC1:: (GateData n) -> [(GateData (S1 n)])
implementECC1 y = [?decoding circuit]:(implementECC1Helper y):[?encoding circuit]
implementECC1Mapper:: [(GateData n)] -> [(GateData (S1 n)])
implementECC1Mapper x = concatMap (implementECC1) x
implementECC2:: (GateData n) -> [(GateData (S2 n)])
implementECC2 y = [?decoding circuit]:(implementECC2Helper y):[?encoding circuit]
implementECC2Mapper:: [(GateData n)] -> [(GateData (S2 n)])
implementECC2Mapper x = concatMap (implementECC2) x
implementECC3:: (GateData n) -> [(GateData (S3 n)])
implementECC3 y = [?decoding circuit]:(implementECC3Helper y):[?encoding circuit]
implementECC3Mapper:: [(GateData n)] -> [(GateData (S3 n)])
implementECC3Mapper x = concatMap (implementECC3) x
implementECC4:: (GateData n) -> [(GateData (S4 n)])
implementECC4 y = [?decoding circuit]:(implementECC4Helper y):[?encoding circuit]
implementECC4Mapper:: [(GateData n)] -> [(GateData (S4 n)])
implementECC4Mapper x = concatMap (implementECC4) x
-}

--Common logical circuits applyed with None as ECCScheme, if want with error correction then apply the corresponding implementECC Mapper in succession
{-
-- quantumFourierTransform N gives the circuit that implements said QFT on N logical qubits indexed as 0 through N-1
-- works inductively bc given as related to (quantumFourierTransform N-1) before any potential simplifications
quantumFourierTransform :: Int -> [GateData None]
quantumFourierTransform 0 = []
quantumFourierTransform 1 = GateData(name=Hadamard1,myinvolvedQubits=[Lgcl 0])
quantumFourierTransform N = GateData(name=Hadamard1,myinvolvedQubits=[Lgcl N-1]):( all the controlled rotations on N-1 and rest): (quantumFourierTransform (N-1))
-- Grover's search takes the black boxed circuit and and integer m which should be O(\sqrt{N}) and produce the grovers Search algorithm circuit
groversSearch :: [GateData None] -> Int -> [GateData None]
-}

-- Reversible circuit for 3-SAT

-- a clause (i, bi, j, bj, k, bk) represents \pm x_i or \pm x_j or \pm x_k
-- where if the corresponding b is True then use + sign
-- otherwise (NOT x_j) for example
--data Clause = ( Int , Bool, Int , Bool, Int, Bool)
--data BooleanFormula = [Clause]

notGate :: Int -> Bool -> [GateData None]
notGate i True = [GateData{name=PauliX1,myinvolvedQubits=[Lgcl i]}]
notGate i False = []

--getCircLHelper :: Clause -> (Int,Int,Int) -> [GateData None]
-- the second argument gives where to put the n+1'st bit, and the 2 ancillas