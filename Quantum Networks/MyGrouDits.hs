module MyGrouDits
( Groudit2by2
) where

import MyGroups

-- https://arxiv.org/pdf/1707.00966.pdf --

data ObjectSet = Slot1 | Slot2 deriving (Eq,Show,Read)

class (Eq a) => FiniteGroupoid2 a where
    groupoidmult :: a -> a -> Maybe a
    groupoidinv :: a -> a
    identityMorphisms :: ObjectSet -> a
    sourceObject :: a -> ObjectSet
    targetObject :: a -> ObjectSet

class (FiniteGroupoid2 a) => FiniteGroudit2 a where
    --Pair of balancers sigma and tau that give bijections G_i with Obj(G)
    sigma :: a -> ObjectSet
    tau :: a -> ObjectSet
    -- if x :: a is x=(g,i) then sigma x is sigma_i (g), these can be reasonably complicated bijections if d big enough
    sigmaInverse :: ObjectSet -> ObjectSet -> a
    tauInverse :: ObjectSet -> ObjectSet -> a
    sigma1 :: a -> (ObjectSet,ObjectSet)
    sigma2 :: (ObjectSet,ObjectSet) -> a
    tau1 :: a -> (ObjectSet,ObjectSet)
    tau2 :: (ObjectSet,ObjectSet) -> a
    -- From these balancers contstruct biunitary
    biunitary :: a -> a

data Groudit2by2 = Groudit2by2 { giPart::CyclicGroup2
                                       , whichObject :: ObjectSet
                                      } deriving (Eq)

instance Show Groudit2by2 where
    show x = (show $ giPart x) ++ " on object " ++ (show $ whichObject x)

instance FiniteGroupoid2 Groudit2by2 where
    groupoidinv a = Groudit2by2 { giPart = inv ( giPart a) , whichObject = whichObject a}
    identityMorphisms b = Groudit2by2 { giPart = identity , whichObject = b}
    sourceObject a = whichObject a
    targetObject a = whichObject a
    groupoidmult a b
                     | (sourceObject a /= targetObject b) = Nothing
                     | otherwise = Just Groudit2by2 { giPart = mult (giPart a) (giPart b) , whichObject = whichObject a}

selectFirstMeetingCriteria :: (Eq b) => [a] -> (a -> b) -> b -> a -> a
selectFirstMeetingCriteria [] _ _ defaultVal = defaultVal
selectFirstMeetingCriteria (x:xs) f myB defaultVal = if (f x == myB) then x else (selectFirstMeetingCriteria xs f myB defaultVal)

mySwap :: (a,b) -> (b,a)
mySwap (x,y) = (y,x)

instance FiniteGroudit2 Groudit2by2 where
    sigma a
        | ((giPart a == Id) && (whichObject a == Slot1)) = Slot1
        | (giPart a == Flip) && (whichObject a == Slot1) = Slot2
        | (giPart a == Id) && (whichObject a == Slot2) = Slot1
        | (giPart a == Flip) && (whichObject a == Slot2) = Slot2
    tau a
         | (giPart a == Id) && (whichObject a == Slot1) = Slot1
         | (giPart a == Flip) && (whichObject a == Slot1) = Slot2
         | (giPart a == Id) && (whichObject a == Slot2) = Slot1
         | (giPart a == Flip) && (whichObject a == Slot2) = Slot2
    sigmaInverse a b = selectFirstMeetingCriteria allPossible sigma b (head allPossible) where allPossible=[Groudit2by2{giPart= x,whichObject=a}| x <- [(toEnum y) :: CyclicGroup2 | y <- [0,1]]]
    tauInverse a b = selectFirstMeetingCriteria allPossible tau b (head allPossible) where allPossible=[Groudit2by2{giPart= x,whichObject=a}| x <- [(toEnum y) :: CyclicGroup2 | y <- [0,1]]]
    sigma1 a = (whichObject a,sigma a)
    tau1 a = (whichObject a,tau a)
    sigma2 (a,b) = sigmaInverse a b
    tau2 (a,b) = tauInverse a b
    biunitary a = tau2 $ mySwap $ sigma1 a