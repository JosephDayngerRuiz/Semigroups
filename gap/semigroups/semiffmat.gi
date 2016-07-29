############################################################################r
##
#W  semiffmat.gi
#Y  Copyright (C) 2015                                   James D. Mitchell
##                                                         Markus Pfeiffer
##
##  Licensing information can be found in the README file of this package.
##
#############################################################################
##

#FIXME There should be methods for random semigroup/monoid

InstallMethod(RandomMatrixSemigroup,
"for a ring, positive integer, and positive integer",
[IsRing, IsPosInt, IsPosInt],
function(R, m, n)
  return Semigroup(List([1 .. m], x -> RandomMatrixOp(R, n)));
end);

InstallMethod(RandomMatrixMonoid,
"for a ring, positive integer, and positive integer",
[IsRing, IsPosInt, IsPosInt],
function(R, m, n)
  return Monoid(List([1 .. m], x -> RandomMatrixOp(R, n)));
end);

InstallMethod(RandomMatrixSemigroup,
"for a ring, positive integer, positive integer, and a list",
[IsRing, IsPosInt, IsPosInt, IsList],
function(R, m, n, ranks)
  return Semigroup(RandomListOfMatricesWithRanks(R, m, n, ranks));
end);

InstallMethod(RandomMatrixMonoid,
"for a ring, positive integer, positive integer, and a list",
[IsRing, IsPosInt, IsPosInt, IsList],
function(R, m, n, ranks)
  return Monoid(RandomListOfMatricesWithRanks(R, m, n, ranks));
end);

InstallMethod(GroupOfUnits, "for an matrix over finite field semigroup",
[IsMatrixSemigroup],
function(S)
  local r, g, e, U;

  e := MultiplicativeNeutralElement(S);

  if e = fail then
    return fail;
  fi;

  r := GreensRClassOfElementNC(S, e);
  g := SchutzenbergerGroup(r);

  U := Monoid(GeneratorsOfGroup(g));

  if not IsGroup(U) then
    SetIsGroupAsSemigroup(U, true);
  fi;
  UseIsomorphismRelation(U, g);

  return U;
end);

InstallMethod(BaseDomain, "for a matrix semigroup",
[IsMatrixSemigroup], S -> BaseDomain(Representative(S)));

InstallMethod(DegreeOfMatrixSemigroup, "for a matrix semigroup",
[IsMatrixSemigroup], S -> DimensionOfMatrixOverSemiring(Representative(S)));

InstallMethod(DimensionOfMatrixOverSemiringCollection, "for a matrix semigroup",
[IsMatrixSemigroup], DegreeOfMatrixSemigroup);

InstallMethod(IsMatrixSemigroupGreensClass, "for a Green's class",
[IsGreensClass], C -> IsMatrixSemigroup(Parent(C)));

InstallTrueMethod(IsGeneratorsOfSemigroup, IsMatrixOverFiniteFieldCollection);

InstallMethod(IsGeneratorsOfInverseSemigroup,
"for an matrix over finite field collection",
[IsMatrixOverFiniteFieldCollection],
function(coll)
  return ForAll(coll, x -> x ^ (-1) <> fail);
end);

#T can we fold this into SemigroupByGenerators maybe?
InstallGlobalFunction(MatrixSemigroup,
function(arg)
  local gens, ring, d;

  if Length(arg) = 1 and IsHomogeneousList(arg[1])
      and IsFFECollCollColl(arg[1]) then
    gens := arg[1];
  elif Length(arg) = 2 and IsField(arg[2]) and
      IsFFECollCollColl(arg[1]) then
    gens := arg[1];
    ring := arg[2];
  else
    ErrorNoReturn("Semigroups: MatrixSemigroup: usage,\n",
                  "either takes a list of standard GAP matrices, or such a ",
                  "list and a ring as arguments,");
  fi;

  if not IsBound(ring) then
     ring := DefaultFieldOfMatrix(Product(gens));
  fi;

  d := Length(gens[1]);

  gens := List(gens,
               x -> NewMatrixOverFiniteField(IsPlistMatrixOverFiniteFieldRep,
                                             ring,
                                             x));
  return Semigroup(gens);
end);

#T is it inconsistent to have the filter first for NewMatrixOverFiniteField
#T but last for isomorphism?
#T Why does it not seem to be possible to do the same as for
#T constructors? IsObject seems a bit out there
# FIXME Change to IsomorphismSemigroup!!
InstallOtherMethod(IsomorphismMatrixSemigroup,
"for a semigroup of matrices and a constructing filter",
[IsSemigroup and HasGeneratorsOfSemigroup and IsFFECollCollColl, IsObject],
function(S, filter)
  local gens, dom, deg, iso;
  dom := DefaultFieldOfMatrix(Representative(S));
  deg := Length(Representative(S));
  iso := x -> NewMatrixOverFiniteField(filter, dom, x);
  gens := List(GeneratorsOfSemigroup(S), iso);
  return MagmaIsomorphismByFunctionsNC(S, Semigroup(gens), iso, AsMatrix);
end);

# This chooses as default representation to be IsPlistMatrixOverFiniteFieldRep
InstallMethod(IsomorphismMatrixSemigroup,
"for a semigroup of matrices",
[IsSemigroup and HasGeneratorsOfSemigroup and IsFFECollCollColl],
function(S)
  return IsomorphismMatrixSemigroup(S, IsPlistMatrixOverFiniteFieldRep);
end);

InstallMethod(IsomorphismMatrixSemigroup,
"for a semigroup with generators",
[IsSemigroup and HasGeneratorsOfSemigroup],
function(S)
    return IsomorphismMatrixSemigroup(S, GF(2));
end);

InstallMethod(IsomorphismMatrixSemigroup,
"for a matrix over finite field semigroup",
[IsMatrixSemigroup and HasGeneratorsOfSemigroup],
function(S)
  return MagmaIsomorphismByFunctionsNC(S, S, IdFunc, IdFunc);
end);

InstallMethod(IsomorphismMatrixSemigroup,
"for a semigroup and a ring",
[IsTransformationSemigroup, IsRing],
function(S, R)
  local n, basis, map, iso, gens;

  n := DegreeOfTransformationSemigroup(S);
  basis := NewIdentityMatrix(IsPlistMatrixRep, R, n);
  map := x -> AsList(basis{ImageListOfTransformation(x, n)});
  iso := x -> NewMatrixOverFiniteField(IsPlistMatrixOverFiniteFieldRep,
                                       R,
                                       map(x));
  gens := List(GeneratorsOfSemigroup(S), iso);

  # gaplint: ignore 2
  return MagmaIsomorphismByFunctionsNC(S, Semigroup(gens), iso,
           x -> Transformation(List(x, PositionNonZero)));
end);

InstallMethod(IsomorphismMatrixSemigroup,
"for a matrix semigroup and a ring",
[IsMatrixSemigroup, IsRing],
function(S, R)
    local f, g;
    if BaseDomain(Representative(S)) = R then
      return MagmaIsomorphismByFunctionsNC(S, S, IdFunc, IdFunc);
    else
      # This is obviously not ideal!
      f := IsomorphismTransformationSemigroup(S);
      g := IsomorphismMatrixSemigroup(Range(f), R);
      return f * g;
    fi;
end);

InstallMethod(IsomorphismMatrixSemigroup,
"for a semigroup and a ring",
[IsSemigroup, IsRing],
function(S, R)
  local map;
  map := IsomorphismTransformationSemigroup(S);
  return map * IsomorphismMatrixSemigroup(Range(map), R);
end);

# FIXME Remove these!

InstallMethod(AsMatrixSemigroup, "for a semigroup", [IsSemigroup],
function(S)
  return Range(IsomorphismMatrixSemigroup(S));
end);

InstallMethod(AsMatrixSemigroup, "for a semigroup and a ring",
[IsSemigroup, IsRing],
function(S, R)
  return Range(IsomorphismMatrixSemigroup(S, R));
end);

#############################################################################
##
## Methods for acting semigroups setup
##
#############################################################################

InstallOtherMethod(FakeOne, "for an matrix over finite field collection",
[IsMatrixOverFiniteFieldCollection],
function(coll)
  if IsGeneratorsOfActingSemigroup(coll) then
    return One(Representative(coll));
  fi;
  return fail;
end);

InstallGlobalFunction(MatrixOverFiniteFieldRowSpaceRightAction,
function(s, vsp, m)
  local nvsp, deg, i;

  # This takes care of the token element
  if Rank(vsp) > DimensionOfMatrixOverSemiring(m) then
    return RowSpaceBasis(m);
  elif Rank(vsp) = 0 then
    return vsp;
  else
    nvsp := SEMIGROUPS_MutableCopyMat(vsp!.rows * m!.mat);
  fi;
  TriangulizeMat(nvsp);

  deg := Length(nvsp);
  for i in [deg, deg - 1 .. 1] do
    if IsZero(nvsp[i]) then
      Remove(nvsp, i);
    fi;
  od;

  return NewRowBasisOverFiniteField(IsPlistRowBasisOverFiniteFieldRep,
                                    BaseDomain(vsp), nvsp);
end);

InstallGlobalFunction(MatrixOverFiniteFieldLocalRightInverse,
function(S, V, mat)
  local n, k, W, se, zv, u, j, i;

  n := DimensionOfMatrixOverSemiring(mat);
  k := Rank(V);

  if n = 0 or k = 0 then
    #FIXME improve this
    ErrorNoReturn("Semigroups: MatrixOverFiniteFieldLocalRightInverse: ",
                  "usage,\n nullspace");
  fi;

  W := SEMIGROUPS_MutableCopyMat(V!.rows * mat);

  for i in [1 .. k] do
    Append(W[i], V!.rows[i]);
  od;
  se := SemiEchelonMat(W);
  # If the matrix does not act injectively on V,
  # then there is no right inverse
  # FIXME: I think we can now simplify things below
  if Number(se.heads{[1 .. n]}, IsZero) > n - k then
    return fail;
  fi;

  for i in [1 .. Length(se.vectors)] do
    W[i] := ShallowCopy(se.vectors[i]);
  od;

  zv := [1 .. 2 * n] * Zero(BaseDomain(mat));
  for i in [1 .. n - Length(W)] do
    Add(W, ShallowCopy(zv));
  od;

  # add missing heads
  u := One(BaseDomain(mat));
  j := k + 1;
  for i in [1 .. n] do
    if se.heads[i] = 0 then
      W[j][i] := u;
      W[j][n + i] := u;
      j := j + 1;
    fi;
  od;
  TriangulizeMat(W);

  return AsMatrix(IsMatrixOverFiniteField, mat, W{[1 .. n]}{[n + 1 .. 2 * n]});
end);

#T returns an invertible matrix
#T make pretty and efficient (in that order)
#T In particular the setup for the matrix should be much more
#T efficient.
InstallGlobalFunction(MatrixOverFiniteFieldSchutzGrpElement,
function(S, x, y)
  local deg, n, eqs, idx, col, row, res;

  deg := DimensionOfMatrixOverSemiring(x);
  n := RowRank(x);

  if n = 0 then
    return
      NewIdentityMatrixOverFiniteField(SEMIGROUPS_FilterOfMatrixOverSemiring(x),
                                       BaseDomain(x),
                                       n);
  else
    eqs := TransposedMatMutable(Concatenation(TransposedMat(x!.mat),
                                              TransposedMat(y!.mat)));
    TriangulizeMat(eqs);

    idx := [];
    col := 1;
    row := 1;

    while col <= deg do
      while IsZero(eqs[row][col]) and col <= deg do
        col := col + 1;
      od;
      if col <= deg then
        Add(idx, col);
        row := row + 1;
        col := col + 1;
      fi;
    od;
    res := NewMatrixOverFiniteField(SEMIGROUPS_FilterOfMatrixOverSemiring(x),
                                    BaseDomain(x),
                                    eqs{[1 .. n]}{idx + deg});

    if res ^ (-1) = fail then
      ErrorNoReturn("Semigroups: MatrixOverFiniteFieldSchutzGrpElement: ",
                    "error,\nthe found element is not invertible,");
    fi;
  fi;

  return res;
end);

## StabilizerAction
InstallGlobalFunction(MatrixOverFiniteFieldStabilizerAction,
function(S, x, m)
  local n, k, rsp, zv, i;

  if IsZero(x) then
    return x;
  fi;
  n := DimensionOfMatrixOverSemiring(m);
  k := RowRank(x);
  rsp := ShallowCopy(m!.mat * RowSpaceBasis(x)!.rows);

  zv := [1 .. n] * Zero(BaseDomain(x));
  for i in [1 .. n - k] do
    Add(rsp, ShallowCopy(zv));
  od;

  return AsMatrix(IsMatrixOverFiniteField,
                  x,
                  RowSpaceTransformationInv(x) * rsp);
end);

# This should be doable in a much more efficient way
InstallGlobalFunction(MatrixOverFiniteFieldLambdaConjugator,
function(S, x, y)
  local res, xse, h, p, yse, q;

  if IsZero(x) then
    res :=
     NewZeroMatrixOverFiniteField(SEMIGROUPS_FilterOfMatrixOverSemiring(x),
                                  BaseDomain(x),
                                  Rank(RowSpaceBasis(x)));
  else
    xse := SemiEchelonMat(SEMIGROUPS_MutableCopyMat(x!.mat));
    h := Filtered(xse.heads, x -> x <> 0);
    p := NewMatrixOverFiniteField(SEMIGROUPS_FilterOfMatrixOverSemiring(x),
                                  BaseDomain(x),
                                  One(BaseDomain(x)) *
                                    PermutationMat(SortingPerm(h),
                                                   Length(h),
                                                   BaseDomain(x)));

    yse := SemiEchelonMat(SEMIGROUPS_MutableCopyMat(y!.mat));
    h := Filtered(yse.heads, x -> x <> 0);
    q := NewMatrixOverFiniteField(SEMIGROUPS_FilterOfMatrixOverSemiring(y),
                                  BaseDomain(y),
                                  One(BaseDomain(y)) *
                                    PermutationMat(SortingPerm(h),
                                                   Length(h),
                                                   BaseDomain(y)));

    res := p * q ^ (-1);
  fi;
  return res;
end);

#T is there a complete direct way of testing whether
#T this idempotent exists (without constructing it)?
#T the method below is already pretty efficient

# TODO: remove redundant S as an argument here.
InstallGlobalFunction(MatrixOverFiniteFieldIdempotentTester,
function(S, x, y)
    return MatrixOverFiniteFieldIdempotentCreator(S, x, y) <> fail;
end);

# Attempt to construct an idempotent m with RowSpace(m) = x
# ColumnSpace(m) = y

InstallGlobalFunction(MatrixOverFiniteFieldIdempotentCreator,
function(S, x, y)
  local filt, m, inv;

  if Rank(x) = 0 then
    filt := SEMIGROUPS_FilterOfMatrixOverSemiring(Representative(S));
    return NewZeroMatrixOverFiniteField(filt,
                                        BaseDomain(S),
                                        DegreeOfMatrixSemigroup(S));
  else
    m := AsMatrix(IsMatrixOverFiniteField,
                  Representative(S),
                  TransposedMat(y!.rows) * x!.rows);
    inv := MatrixOverFiniteFieldLocalRightInverse(S, x, m);
    if inv = fail then
      return fail;
    else
      return m * inv;
    fi;
  fi;
end);

#TODO this method is probably redundant.

InstallMethod(ViewString,
"for an matrix over finite field semigroup with generators",
[IsMatrixSemigroup and HasGeneratorsOfSemigroup],
function(S)
  local gens, deg, res;
  if HasIsMonoid(S) and IsMonoid(S) then
    gens := GeneratorsOfMonoid(S);
    deg := DimensionOfMatrixOverSemiring(gens[1]);
    res := "<monoid of ";
    Append(res, Concatenation(String(deg), "x", String(deg)));
    Append(res, " matrices\<\> over ");
    Append(res, String(BaseDomain(S)));
    Append(res, Concatenation("\<\> with ", Length(gens), " generator"));
  else
    gens := GeneratorsOfSemigroup(S);
    deg := DimensionOfMatrixOverSemiring(gens[1]);
    res := "<semigroup of ";
    Append(res, Concatenation(String(deg), "x", String(deg)));
    Append(res, " matrices\<\> over ");
    Append(res, String(BaseDomain(S)));
    Append(res, Concatenation("\<\> with ", Length(gens), " generator"));
  fi;
  if Length(gens) > 1 then
    Append(res, "s");
  fi;
  Append(res, ">");
  return res;
end);

InstallMethod(ViewObj,
"for an matrix over finite field semigroup with generators",
[IsMatrixSemigroup and HasGeneratorsOfSemigroup],
function(S)
  local gens, deg;
  if HasIsMonoid(S) and IsMonoid(S) then
    gens := GeneratorsOfMonoid(S);
    deg := DimensionOfMatrixOverSemiring(gens[1]);
    Print("<monoid of ");
    Print(deg, "x", deg);
    Print(" matrices\<\> over ", BaseDomain(S));
    Print("\<\> with ", Length(gens), " generator");
  else
    gens := GeneratorsOfSemigroup(S);
    deg := DimensionOfMatrixOverSemiring(gens[1]);
    Print("<semigroup of ");
    Print(deg, "x", deg);
    Print(" matrices\<\> over ", BaseDomain(S));
    Print("\<\> with ", Length(gens), " generator");
  fi;
  if Length(gens) > 1 then
    Print("s");
  fi;
  Print(">");
end);

InstallMethod(PrintObj, "for a matrix semigroup with generators",
[IsMatrixSemigroup and HasGeneratorsOfSemigroup],
function(S)
  Print("Semigroup(", GeneratorsOfSemigroup(S), ")");
end);

InstallMethod(ViewObj,
"for a matrix semigroup ideal with generators of semigroup ideal",
[IsMatrixSemigroup and IsSemigroupIdeal and HasGeneratorsOfSemigroupIdeal],
function(S)
  local deg, gens;
  gens := GeneratorsOfSemigroupIdeal(S);
  deg := DimensionOfMatrixOverSemiring(gens[1]);
  Print("<ideal of semigroup of ");
  Print(deg, "x", deg);
  Print(" matrices over ", BaseDomain(gens[1]));
  Print(" with ", Length(gens), " generator");

  if Length(gens) > 1 then
    Print("s");
  fi;
  Print(">");
end);

InstallMethod(IsGeneratorsOfSemigroup,
"for an matrix over finite field collection",
[IsMatrixOverFiniteFieldCollection],
function(coll)
  if ForAny(coll, x -> DimensionOfMatrixOverSemiring(x)
                         <> DimensionOfMatrixOverSemiring(coll[1])
                       or BaseDomain(x) <> BaseDomain(coll[1])) then
    return false;
  fi;
  return true;
end);