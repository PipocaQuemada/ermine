
--------------------------------------------------------------------
-- |
-- Copyright :  (c) Dan Doel 2013
-- License   :  BSD2
-- Maintainer:  Dan Doel <dan.doel@gmail.com>
-- Stability :  experimental
-- Portability: non-portable
--
-- This module provides the parser for types
--------------------------------------------------------------------
module Ermine.Parser.Data
  ( constr
  , dataType
  ) where

import Bound
import Bound.Var (unvar)
import Control.Applicative
import Control.Lens
import Data.List
import Data.Maybe
import Data.Text (Text, unpack)
import Ermine.Parser.Global
import Ermine.Parser.Style
import Ermine.Parser.Type
import Ermine.Syntax.Constructor
import Ermine.Syntax.Data
import Ermine.Syntax.Kind (HasKindVars(..))
import Ermine.Syntax.Type
import Text.Parser.Combinators
import Text.Parser.Token

-- | Abstract from a list of bound variables
abstractSimple :: Eq v => [v] -> v -> Var Int v
abstractSimple l v = maybe (F v) B $ elemIndex v l

-- | Parse a data constructor
constr :: (Monad m, TokenParsing m) => m (Constructor (Maybe Text) (Var Text Text))
constr = build . fromMaybe ([], [])
     <$> optional (quantifier "forall")
     <*> globalIdent termCon
     <*> many typ0
 where
 build (ks, ts) g as = Constructor g (map Just ks) ts' as'
  where
  ts' = map (bimap (unvar Just Just) (abstract (`elemIndex` map Just ks))) ts
  as' = abstract (`elemIndex` map fst ts) . abstractKinds (`elemIndex` map Just ks) <$> as

-- | Data a data declaration
dataType :: (Monad m, TokenParsing m) => m (DataType () Text)
dataType = build <$ symbol "data"
       <*> globalIdent typeCon
       <*> typVarBindings
       <*> (fromMaybe [] <$> optional (symbolic '=' *> sepBy constr (symbolic '|')))
 where
 build nm ts cs = bimap semiClosedKind semiClosedType $ DataType nm (map Just ks) ts' cs'
  where
  ks  = nub . catMaybes $ toListOf kindVars (snd <$> ts, cs)
  jks = Just <$> ks
  ts' = map (bimap (unvar Just Just) (abstract (`elemIndex` jks))) ts
  cs' = bimap (abstractSimple jks) (abstractSimple $ map fst ts) <$> cs
  semiClosedKind (Just _) = error "dataType: Impossible kind"
  semiClosedKind Nothing  = ()
  semiClosedType (B v) = error $ "Unbound type variable: " ++ unpack v
  semiClosedType (F x) = x
