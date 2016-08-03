############################################################################
##
#W  congruences/congpairs.gi
#Y  Copyright (C) 2015                                   Michael C. Torpey
##
##  Licensing information can be found in the README file of this package.
##
#############################################################################
##
## This file contains functions for any finite semigroup congruence with
## generating pairs, using a pair enumeration and union-find method.
##
#############################################################################
##
## A congruence here is defined by a semigroup and a list of generating pairs.
## Most of the work is done by SEMIGROUPS_Enumerate, a hidden function which
## begins to multiply known pairs in the congruence by the semigroup's
## generators, checking its results periodically against a supplied "lookfunc"
## which checks whether some condition has been fulfilled.
##
## Any function which requires information about a congruence may call
## SEMIGROUPS_Enumerate with a lookfunc to allow it to terminate as soon as the
## necessary information is found, without doing extra work.  Information found
## so far is then stored in a "congruence data" object, and work may be resumed
## in subsequent calls to SEMIGROUPS_Enumerate.
##
## If all the pairs of the congruence have been found, the congruence data
## object is discarded, and a lookup table is stored, giving complete
## information about the congruence classes.  If a lookup table is available,
## it is always used instead of SEMIGROUPS_Enumerate, which will always return
## fail from then on.
##
## Most methods in this file apply to (two-sided) congruences, as well as left
## congruences and right congruences.  The _InstallMethodsForCongruences
## function is called three times when Semigroups is loaded, installing slightly
## different methods for left, right, and two-sided congruences.  Of course a
## left congruence may turn out also to be a right congruence, and so on, but
## the properties HasGeneratingPairsOf(Left/Right)MagmaCongruence allow us to
## determine which type of relation we are treating it as.
##
## See J.M. Howie's "Fundamentals of Semigroup Theory" Section 1.5, and see
## Michael Torpey's MSc thesis "Computing with Semigroup Congruences" Chapter 2
## (www-circa.mcs.st-and.ac.uk/~mct25/files/mt5099-report.pdf) for more details.
##
#############################################################################

# This function creates the congruence data object for cong.  It should only
# be called once.

InstallMethod(SemigroupCongruenceByGeneratingPairs, 
"for a semigroup and list of generating pairs", IsElmsColls,
[IsSemigroup, IsList],
function(S, genpairs)
local fam, cong, type, pair;

  if not IsFinite(S) then 
    TryNextMethod();
  fi;
  
  # Check that the pairs are all lists of length length 2
  for pair in genpairs do
    if not IsList(pair) or Length(pair) <> 2 
        or not pair[1] in S or not pair[2] in S then
      ErrorNoReturn("");
    fi;
  od;

  fam := GeneralMappingsFamily(ElementsFamily(FamilyObj(S)),
                               ElementsFamily(FamilyObj(S)));

  # Create the default type for the elements.
  cong := Objectify(NewType(fam,
          IsFiniteCongruenceByGeneratingPairsRep and
          IsSemigroupCongruence), 
                    rec(genpairs := Immutable(genpairs), 
                        report := SEMIGROUPS.OptionsRec(S).report,
                        type := "twosided",
                        range := GenericSemigroupData(S)));
  SetSource(cong, S);
  SetRange(cong, S);
  SetGeneratingPairsOfMagmaCongruence(cong, Immutable(genpairs));
  
  # TODO put this in the C code
  cong!.factored_genpairs := List(genpairs, x -> [MinimalFactorization(S, x[1]), 
                                                  MinimalFactorization(S, x[2])]);

  return cong;
end);

InstallMethod(IsRightSemigroupCongruence,
"for a left semigroup congruence with known generating pairs",
[IsLeftSemigroupCongruence and HasGeneratingPairsOfLeftMagmaCongruence],
function(congl)
  local pairs, cong2;
  # Is this left congruence right-compatible?
  # First, create the 2-sided congruence generated by these pairs.
  pairs := GeneratingPairsOfLeftSemigroupCongruence(congl);
  cong2 := SemigroupCongruence(Range(congl), pairs);

  # congl is right-compatible iff these describe the same relation
  if congl = cong2 then
    SetGeneratingPairsOfMagmaCongruence(congl, pairs);
    SetIsSemigroupCongruence(congl, true);
    return true;
  else
    SetIsSemigroupCongruence(congl, false);
    return false;
  fi;
end);

InstallMethod(IsLeftSemigroupCongruence,
"for a right semigroup congruence with known generating pairs",
[IsRightSemigroupCongruence and HasGeneratingPairsOfRightMagmaCongruence],
function(congr)
  local pairs, cong2;
  # Is this right congruence left-compatible?
  # First, create the 2-sided congruence generated by these pairs.
  pairs := GeneratingPairsOfRightSemigroupCongruence(congr);
  cong2 := SemigroupCongruence(Range(congr), pairs);

  # congr is left-compatible iff these describe the same relation
  if congr = cong2 then
    SetGeneratingPairsOfMagmaCongruence(congr, pairs);
    SetIsSemigroupCongruence(congr, true);
    return true;
  else
    SetIsSemigroupCongruence(congr, false);
    return false;
  fi;
end);

InstallMethod(IsSemigroupCongruence,
"for a left semigroup congruence with known generating pairs",
[IsLeftSemigroupCongruence and HasGeneratingPairsOfLeftMagmaCongruence],
function(cong)
  return IsRightSemigroupCongruence(cong);
end);

InstallMethod(IsSemigroupCongruence,
"for a right semigroup congruence with known generating pairs",
[IsRightSemigroupCongruence and HasGeneratingPairsOfRightMagmaCongruence],
function(cong)
  return IsLeftSemigroupCongruence(cong);
end);


# _GenericCongruenceEquality tests equality for any combination of left, right
# and 2-sided congruences, so it is installed for the six combinations below.
# If the arguments are the same type of congruence, a different method is used


################################################################################
# We now have some methods which apply to left congruences, right congruences
# and 2-sided congruences.  These functions behave only slightly differently for
# these three types of object, so they are installed by the function
# _InstallMethodsForCongruences, which takes a record describing the type of
# object the filters apply to (left, right, or 2-sided).
#
# See below for the loop where this function is invoked. It is required to do
# this in a function so that the values _record,
# _GeneratingPairsOfXSemigroupCongruence, etc are available (as local
# variables in the function) when the methods installed in this function are
# actually called. If we don't use a function here, the values in _record etc
# are unbound by the time the methods are called.
################################################################################

BindGlobal("_InstallMethodsForCongruences",
function(_record)
  local _GeneratingPairsOfXSemigroupCongruence,
        _HasGeneratingPairsOfXSemigroupCongruence,
        _XSemigroupCongruence,
        _IsXSemigroupCongruence,
        _IsXCongruenceClass;

  _GeneratingPairsOfXSemigroupCongruence :=
    EvalString(Concatenation("GeneratingPairsOf",
                             _record.type_string,
                             "MagmaCongruence"));
  _HasGeneratingPairsOfXSemigroupCongruence :=
    EvalString(Concatenation("HasGeneratingPairsOf",
                             _record.type_string,
                             "MagmaCongruence"));
  _XSemigroupCongruence :=
    EvalString(Concatenation(_record.type_string,
                             "SemigroupCongruence"));
  _IsXSemigroupCongruence :=
    EvalString(Concatenation("Is",
                             _record.type_string,
                             "SemigroupCongruence"));
  _IsXCongruenceClass :=
    EvalString(Concatenation("Is",
                             _record.type_string,
                             "CongruenceClass"));

  #


  #

  SEMIGROUPS.IsPairInXCong := function(pair, cong)
    local S, p1, p2, table, lookfunc;

    S := Range(cong);
    p1 := Position(GenericSemigroupData(S), pair[1]);
    p2 := Position(GenericSemigroupData(S), pair[2]);

    # Use lookup table if available
    if HasAsLookupTable(cong) then
      table := AsLookupTable(cong);
      return table[p1] = table[p2];
    else
      # Otherwise, begin calculating the lookup table and look for this pair
      lookfunc := function(data)
        return UF_FIND(data!.ufdata, p1)
               = UF_FIND(data!.ufdata, p2);
      end;
      return SEMIGROUPS_Enumerate(cong, lookfunc)!.found;
    fi;
  end;

  #


  #

  InstallMethod(SEMIGROUPS_Enumerate,
  Concatenation("for a ", _record.info_string, "semigroup congruence",
                " with known generating pairs and a function"),
  [_IsXSemigroupCongruence and _HasGeneratingPairsOfXSemigroupCongruence,
   IsFunction],
  function(cong, lookfunc)
    # If we have a lookup table, then we have complete information
    # and there is nothing left to enumerate
    if HasAsLookupTable(cong) then
      return fail;
    fi;
    # If the congruence data does not exist, then we need to set it up
    if not IsBound(cong!.data) then
      SEMIGROUPS.SetupCongData(cong);
    fi;
    return SEMIGROUPS_Enumerate(cong!.data, lookfunc);
  end);

  #


  #


  #


  #


  #

  InstallMethod(ViewObj,
  Concatenation("for a ", _record.info_string,
                "semigroup congruence with generating pairs"),
  [_IsXSemigroupCongruence and _HasGeneratingPairsOfXSemigroupCongruence],
  function(cong)
    Print("<", _record.info_string, "semigroup congruence over ");
    ViewObj(Range(cong));
    Print(" with ", Size(_GeneratingPairsOfXSemigroupCongruence(cong)),
          " generating pairs>");
  end);

  #


  #

  #TODO: A method for MeetXSemigroupCongruences

  #

  InstallMethod(IsSubrelation,
  Concatenation("for two ", _record.info_string,
                "semigroup congruences with generating pairs"),
  [_IsXSemigroupCongruence and _HasGeneratingPairsOfXSemigroupCongruence,
   _IsXSemigroupCongruence and _HasGeneratingPairsOfXSemigroupCongruence],
  function(cong1, cong2)
    # Tests whether cong1 contains all the pairs in cong2
    if Range(cong1) <> Range(cong2) then
      ErrorNoReturn("Semigroups: IsSubrelation: usage,\n",
                    "congruences must be defined over the same semigroup,");
    fi;
    return ForAll(_GeneratingPairsOfXSemigroupCongruence(cong2),
                  pair -> SEMIGROUPS.IsPairInXCong(pair, cong1));
  end);

  #

  ###########################################################################
  # LatticeOfXCongruences
  ###########################################################################
  
  InstallMethod(EvalString(
  Concatenation("LatticeOf", _record.type_string, "Congruences")),
  "for a semigroup",
  [IsSemigroup],
  S -> SEMIGROUPS.LatticeOfXCongruences(S, _record.type_string, rec()));

  ###########################################################################
  # XCongruencesOfSemigroup
  ###########################################################################
  
  InstallMethod(EvalString(
  Concatenation(_record.type_string, "CongruencesOfSemigroup")),
  "for a semigroup",
  [IsSemigroup],
  function(S)
    local lattice_func;
    if not IsFinite(S) then
      TryNextMethod();
    fi;
    # Find the lattice of congruences, and retrieve
    # the list of congruences from inside it
    lattice_func := EvalString(Concatenation("LatticeOf",
                                             _record.type_string,
                                             "Congruences"));
    return lattice_func(S)![2];
  end);

  ###########################################################################
  # MinimalXCongruencesOfSemigroup
  ###########################################################################
  InstallMethod(EvalString(
  Concatenation("Minimal", _record.type_string, "CongruencesOfSemigroup")),
  "for a semigroup",
  [IsSemigroup],
  function(S)
    local lattice;
    if not IsFinite(S) then
      TryNextMethod();
    fi;
    # Find the lattice of congruences, and retrieve
    # the list of congruences from inside it
    lattice := SEMIGROUPS.LatticeOfXCongruences(S, _record.type_string,
                                                rec(minimal := true));
    return lattice![2];
  end);

  ###########################################################################
  # methods for classes
  ###########################################################################

  InstallMethod(EquivalenceClassOfElement,
  Concatenation("for a ", _record.info_string, "semigroup congruence",
                " with generating pairs and an associative element"),
  [_IsXSemigroupCongruence and _HasGeneratingPairsOfXSemigroupCongruence,
   IsMultiplicativeElement],
  function(cong, elm)
    if not elm in Range(cong) then
      ErrorNoReturn("Semigroups: EquivalenceClassOfElement: usage,\n",
                    "the second arg <elm> must be in the ",
                    "semigroup of the first arg <cong>,");
    fi;
    return EquivalenceClassOfElementNC(cong, elm);
  end);

  #

  InstallMethod(EquivalenceClassOfElementNC,
  Concatenation("for a ", _record.info_string, "semigroup congruence",
                " with generating pairs and an associative element"),
  [_IsXSemigroupCongruence and _HasGeneratingPairsOfXSemigroupCongruence,
   IsMultiplicativeElement],
  function(cong, elm)
    local fam, class;
    fam := FamilyObj(Range(cong));
    class := Objectify(NewType(fam, _IsXCongruenceClass
                               and IsEquivalenceClassDefaultRep),
                       rec(rep := elm));
    SetParentAttr(class, Range(cong));
    SetEquivalenceClassRelation(class, cong);
    SetRepresentative(class, elm);
    if HasIsFinite(Range(cong)) and IsFinite(Range(cong)) then
      SetIsFinite(class, true);
    fi;
    return class;
  end);

  #

  InstallMethod(\in,
  Concatenation("for an associative element and a ",
                _record.info_string, "congruence class"),
  [IsMultiplicativeElement, _IsXCongruenceClass],
  function(elm, class)
    if not IsFinite(Parent(class)) then
      TryNextMethod();
    fi;
    return [elm, Representative(class)] in EquivalenceClassRelation(class);
  end);

  #

  InstallMethod(Size,
  Concatenation("for a ", _record.info_string, "congruence class"),
  [_IsXCongruenceClass],
  function(class)
    local p, tab;
    if not IsFinite(Parent(class)) then
      TryNextMethod();
    fi;
    p := Position(GenericSemigroupData(Parent(class)), Representative(class));
    tab := AsLookupTable(EquivalenceClassRelation(class));
    return Number(tab, n -> n = tab[p]);
  end);

  #

  InstallMethod(\=,
  Concatenation("for two ", _record.info_string, "congruence classes"),
  [_IsXCongruenceClass, _IsXCongruenceClass],
  function(class1, class2)
    if EquivalenceClassRelation(class1) <> EquivalenceClassRelation(class2) then
      return false;
    fi;
    return SEMIGROUPS.IsPairInXCong(
              [Representative(class1), Representative(class2)],
              EquivalenceClassRelation(class1));
  end);

  #

  InstallMethod(AsList,
  Concatenation("for a ", _record.info_string, "congruence class"),
  [_IsXCongruenceClass],
  function(class)
    return ImagesElm(EquivalenceClassRelation(class), Representative(class));
  end);

  InstallMethod(Enumerator,
  Concatenation("for a ", _record.info_string, "congruence class"),
  [_IsXCongruenceClass], AsList);

  #

end);
# End of _InstallMethodsForCongruences function

for _record in [rec(type_string := "",
                    info_string := ""),
                rec(type_string := "Left",
                    info_string := "left "),
                rec(type_string := "Right",
                    info_string := "right ")] do
  _InstallMethodsForCongruences(_record);
od;

Unbind(_record);
MakeReadWriteGlobal("_InstallMethodsForCongruences");
UnbindGlobal("_InstallMethodsForCongruences");

# Multiplication for congruence classes: only makes sense for 2-sided
InstallMethod(\*,
"for two congruence classes",
[IsCongruenceClass, IsCongruenceClass],
function(class1, class2)
  if EquivalenceClassRelation(class1) <> EquivalenceClassRelation(class2) then
    ErrorNoReturn("Semigroups: \*: usage,\n",
                  "the args must be classes of the same congruence,");
  fi;
  return CongruenceClassOfElement(EquivalenceClassRelation(class1),
                                  Representative(class1) *
                                  Representative(class2));
end);

###########################################################################
# IsSubrelation methods between 1-sided and 2-sided congruences
###########################################################################
InstallMethod(IsSubrelation,
"for semigroup congruence and left semigroup congruence",
[IsSemigroupCongruence and HasGeneratingPairsOfMagmaCongruence,
 IsLeftSemigroupCongruence and HasGeneratingPairsOfLeftMagmaCongruence],
function(cong, lcong)
  # Tests whether cong contains all the pairs in lcong
  if Range(cong) <> Range(lcong) then
    ErrorNoReturn("Semigroups: IsSubrelation: usage,\n",
                  "congruences must be defined over the same semigroup,");
  fi;
  return ForAll(GeneratingPairsOfLeftSemigroupCongruence(lcong),
                pair -> SEMIGROUPS.IsPairInXCong(pair, cong));
end);

InstallMethod(IsSubrelation,
"for semigroup congruence and right semigroup congruence",
[IsSemigroupCongruence and HasGeneratingPairsOfMagmaCongruence,
 IsRightSemigroupCongruence and HasGeneratingPairsOfRightMagmaCongruence],
function(cong, rcong)
  # Tests whether cong contains all the pairs in rcong
  if Range(cong) <> Range(rcong) then
    ErrorNoReturn("Semigroups: IsSubrelation: usage,\n",
                  "congruences must be defined over the same semigroup,");
  fi;
  return ForAll(GeneratingPairsOfRightSemigroupCongruence(rcong),
                pair -> SEMIGROUPS.IsPairInXCong(pair, cong));
end);

###########################################################################
# Some individual methods for congruences
###########################################################################

InstallMethod(PrintObj,
"for a left semigroup congruence with known generating pairs",
[IsLeftSemigroupCongruence and HasGeneratingPairsOfLeftMagmaCongruence],
function(cong)
  Print("LeftSemigroupCongruence( ");
  PrintObj(Range(cong));
  Print(", ");
  Print(GeneratingPairsOfLeftSemigroupCongruence(cong));
  Print(" )");
end);

InstallMethod(PrintObj,
"for a right semigroup congruence with known generating pairs",
[IsRightSemigroupCongruence and HasGeneratingPairsOfRightMagmaCongruence],
function(cong)
  Print("RightSemigroupCongruence( ");
  PrintObj(Range(cong));
  Print(", ");
  Print(GeneratingPairsOfRightSemigroupCongruence(cong));
  Print(" )");
end);

InstallMethod(PrintObj,
"for a semigroup congruence with known generating pairs",
[IsSemigroupCongruence and HasGeneratingPairsOfMagmaCongruence],
function(cong)
  Print("SemigroupCongruence( ");
  PrintObj(Range(cong));
  Print(", ");
  Print(GeneratingPairsOfSemigroupCongruence(cong));
  Print(" )");
end);

###############################################################################
# LatticeOfXCongruences function
###############################################################################
# This abstract function takes a semigroup 'S', a string 'type_string' and a
# record 'record'.
# type_string should be in ["Left", "Right", ""] and describes the sort of
# relations we want to find (respectively: left congruences, right congruences,
# two-sided congruences), referred to as 'x congs' below.
# record may contain any of the following components, which should be set to
# 'true' to have the stated effect:
#   * minimal - Return only minimal x-congs
#   * 1gen - Return only x-congs with a single generating pair
#   * transrep - Return only x-congs which contain no 2-sided congruences
###############################################################################
SEMIGROUPS.LatticeOfXCongruences := function(S, type_string, record)
  local transrep, _XSemigroupCongruence, elms, pairs, congs1, nrcongs, children,
        parents, pair, badcong, newchildren, newparents, newcong, i, c, p,
        congs, 2congs, image, next, set_func, lattice, join_func, length, found,
        ignore, start, j, k;

  transrep := IsBound(record.transrep) and record.transrep;
  _XSemigroupCongruence := EvalString(Concatenation(type_string,
                                                    "SemigroupCongruence"));
  elms := SEMIGROUP_AS_LIST(GenericSemigroupData(S));

  # Get all non-reflexive pairs in SxS
  pairs := Combinations(elms, 2);

  # Get all the unique 1-generated congs
  Info(InfoSemigroups, 1, "Getting all 1-generated congs...");
  congs1 := [];     # List of all congs found so far
  nrcongs := 0;     # Number of congs found so far
  children := [];   # List of lists of children
  parents := [];    # List of lists of parents
  for pair in pairs do
    badcong := false;
    newchildren := []; # Children of newcong
    newparents := [];  # Parents of newcong
    newcong := _XSemigroupCongruence(S, pair);
    for i in [1 .. Length(congs1)] do
      if IsSubrelation(congs1[i], newcong) then
        if IsSubrelation(newcong, congs1[i]) then
          # This is not a new cong - drop it!
          badcong := true;
          break;
        else
          Add(newparents, i);
        fi;
      elif IsSubrelation(newcong, congs1[i]) then
        Add(newchildren, i);
      fi;
    od;
    if not badcong then
      nrcongs := nrcongs + 1;
      congs1[nrcongs] := newcong;
      children[nrcongs] := newchildren;
      parents[nrcongs] := newparents;
      for c in newchildren do
        Add(parents[c], nrcongs);
      od;
      for p in newparents do
        Add(children[p], nrcongs);
      od;
    fi;
  od;

  congs := ShallowCopy(congs1);
  if transrep then
    # Find and remove any 2-sided congruences, and discard their parents
    2congs := Set([]);
    for i in [1 .. Length(congs)] do
      if not IsBound(congs[i]) then
        continue;
      fi;
      if IsSemigroupCongruence(congs[i]) then
        # Remove it from the list
        Unbind(congs[i]);
        # Remove all its parents
        for p in parents[i] do
          Unbind(congs[p]);
          if p in 2congs then
            RemoveSet(2congs, p);
          fi;
        od;
        # Store it unless it has 2-sided children
        if ForAll(children[i], c -> not c in 2congs) then
          AddSet(2congs, i);
        fi;
      fi;
    od;

    # Remove holes from congs and change children and parents appropriately
    image := ListWithIdenticalEntries(nrcongs, fail);
    next := 1;
    for i in [1 .. nrcongs] do
      if IsBound(congs[i]) then
        image[i] := next;
        next := next + 1;
      else
        Unbind(parents[i]);
        Unbind(children[i]);
        nrcongs := nrcongs - 1;
      fi;
    od;
    congs := Compacted(congs);
    parents := Compacted(parents);
    children := Compacted(children);
    parents := List(parents, l -> Filtered(List(l, i -> image[i]),
                                           i -> i <> fail));
    children := List(children, l -> Filtered(List(l, i -> image[i]),
                                             i -> i <> fail));
    2congs := List(2congs, i -> congs1[i]);
    congs1 := congs;
  fi;

  # We now have all 1-generated congs, which must include all the minimal
  # congs.  We can return if necessary.
  if IsBound(record.minimal) and record.minimal = true then
    # Find all the minimal congs (those with no children)
    congs := congs{Positions(children, [])};
    # Note: we don't include the trivial cong
    # Set the MinimalXCongruencesOfSemigroup attribute
    set_func := EvalString(Concatenation("SetMinimal",
                                         type_string,
                                         "CongruencesOfSemigroup"));
    set_func(S, congs);
    # Minimal congs cannot contain each other
    children := ListWithIdenticalEntries(Length(congs), []);
    lattice := Objectify(NewType(FamilyObj(children),
                                 IsCongruenceLattice),
                         [children, congs]);
    return lattice;
  elif IsBound(record.1gen) and record.1gen = true then
    # Add the trivial cong at the start
    children := Concatenation([[]], children + 1);
    for i in [2 .. nrcongs + 1] do
      Add(children[i], 1, 1);
    od;
    Add(congs, _XSemigroupCongruence(S, []), 1);
    # Return the lattice, but don't set any attributes
    lattice := Objectify(NewType(FamilyObj(children),
                                 IsCongruenceLattice),
                         [children, congs]);
    return lattice;
  fi;

  # Take all their joins
  Info(InfoSemigroups, 1, "Taking joins...");
  join_func := EvalString(Concatenation("Join",
                                        type_string,
                                        "SemigroupCongruences"));
  length := 0;
  found := true;
  # 'ignore' is a list of congs that we don't try joining
  ignore := BlistList(congs, []);
  while found do
    # There are new congs to try joining
    start := length + 1;     # New congs start here
    found := false;          # Have we found any more congs on this sweep?
    length := Length(congs); # Remember starting position for next sweep
    for i in [start .. Length(congs)] do # for each new cong
      for j in [1 .. Length(congs1)] do  # for each 1-generated cong
        newcong := join_func(congs[i], congs1[j]);
        badcong := false;  # Is newcong the same as another cong?
        newchildren := []; # Children of newcong
        newparents := [];  # Parents of newcong
        for k in [1 .. Length(congs)] do
          if IsSubrelation(congs[k], newcong) then
            if IsSubrelation(newcong, congs[k]) then
              # This is the same as an old cong - discard it!
              badcong := true;
              break;
            else
              Add(newparents, k);
            fi;
          elif IsSubrelation(newcong, congs[k]) then
            Add(newchildren, k);
          fi;
        od;
        # Check for 2-sided congs if 'transrep' is set
        if transrep then
          if IsSemigroupCongruence(newcong) then
            badcong := true;
            Add(2congs, newcong);
            for p in newparents do
              ignore[p] := true;
            od;
          elif ForAny(2congs, c2 -> IsSubrelation(newcong, c2)) then
            badcong := true;
          fi;
        fi;
        if not badcong then
          nrcongs := nrcongs + 1;
          congs[nrcongs] := newcong;
          children[nrcongs] := newchildren;
          parents[nrcongs] := newparents;
          ignore[nrcongs] := false;
          for c in newchildren do
            Add(parents[c], nrcongs);
          od;
          for p in newparents do
            Add(children[p], nrcongs);
          od;
          found := true;
        fi;
      od;
    od;
  od;

  if transrep and (true in ignore) then
    # Remove any congs in 'ignore'
    for i in [1 .. Length(congs)] do
      if ignore[i] then
        Unbind(congs[i]);
      fi;
    od;

    # Remove holes from congs and change children and parents appropriately
    image := ListWithIdenticalEntries(nrcongs, fail);
    next := 1;
    for i in [1 .. nrcongs] do
      if not ignore[i] then
        image[i] := next;
        next := next + 1;
      else
        Unbind(parents[i]);
        Unbind(children[i]);
        nrcongs := nrcongs - 1;
      fi;
    od;
    congs := Compacted(congs);
    parents := Compacted(parents);
    children := Compacted(children);
    parents := List(parents, l -> Filtered(List(l, i -> image[i]),
                                           i -> i <> fail));
    children := List(children, l -> Filtered(List(l, i -> image[i]),
                                             i -> i <> fail));
  fi;

  # Add the trivial cong at the start
  children := Concatenation([[]], children + 1);
  for i in [2 .. nrcongs + 1] do
    Add(children[i], 1, 1);
  od;
  Add(congs, _XSemigroupCongruence(S, []), 1);

  # We have a list of all the congs
  set_func := EvalString(Concatenation("Set",
                                       type_string,
                                       "CongruencesOfSemigroup"));
  set_func(S, congs);

  # Objectify the result
  lattice := Objectify(NewType(FamilyObj(children),
                               IsCongruenceLattice),
                       [children, congs]);
  return lattice;
end;

InstallMethod(DotString,
"for a congruence lattice",
[IsCongruenceLattice],
function(latt)
  # Call the below function, with info turned off
  return DotString(latt, rec(info := false));
end);

InstallMethod(DotString,
"for a congruence lattice and a record",
[IsCongruenceLattice, IsRecord],
function(latt, opts)
  local congs, S, symbols, i, nr, rel, str, j, k;
  # If the user wants info, then change the node labels
  if opts.info = true then
    # The congruences are stored inside the lattice object
    congs := latt![2];
    S := Range(congs[1]);
    symbols := EmptyPlist(Length(latt));
    for i in [1 .. Length(latt)] do
      nr := NrEquivalenceClasses(congs[i]);
      if nr = 1 then
        symbols[i] := "U";
      elif nr = Size(S) then
        symbols[i] := "T";
      elif IsReesCongruence(congs[i]) then
        symbols[i] := Concatenation("R", String(i));
      else
        symbols[i] := String(i);
      fi;
    od;
  else
    symbols := List([1 .. Length(latt)], String);
  fi;

  rel := List([1 .. Length(latt)], x -> Filtered(latt[x], y -> x <> y));
  str := "";

  if Length(rel) < 40 then
    Append(str, "//dot\ngraph graphname {\n     node [shape=circle]\n");
  else
    Append(str, "//dot\ngraph graphname {\n     node [shape=point]\n");
  fi;

  for i in [1 .. Length(rel)] do
    j := Difference(rel[i], Union(rel{rel[i]}));
    i := symbols[i];
    for k in j do
      k := symbols[k];
      Append(str, Concatenation(i, " -- ", k, "\n"));
    od;
  od;

  Append(str, " }");

  return str;
end);
  
InstallMethod(\in,
"for dense list and finite semigroup congruence by generating pairs rep",
[IsDenseList, IsFiniteCongruenceByGeneratingPairsRep],
function(pair, cong)
  local S;
  S := Range(cong);
  if Size(pair) <> 2 then
    ErrorNoReturn("Semigroups: \\in (for a congruence): usage,\n",
    "the first arg <pair> must be a list of length 2,");
  fi;
  if not (pair[1] in S and pair[2] in S) then
    ErrorNoReturn("Semigroups: \\in (for a congruence): usage,\n",
    "elements of the first arg <pair> must be\n",
    "in the range of the second arg <cong>,");
  fi;
  return FIN_CONG_PAIR_IN(cong, List(pair, x -> MinimalFactorization(S, x)));
end);

InstallMethod(NrEquivalenceClasses,
"for a finite semigroup congruence by generating pairs rep",
[IsFiniteCongruenceByGeneratingPairsRep], FIN_CONG_NR_CLASSES);
  
InstallMethod(AsLookupTable,
"for a finite semigroup congruence by generating pairs rep",
[IsFiniteCongruenceByGeneratingPairsRep], FIN_CONG_LOOKUP);

InstallMethod(\=, "for finite semigroup congruences by generating pairs rep",
[IsFiniteCongruenceByGeneratingPairsRep,
 IsFiniteCongruenceByGeneratingPairsRep],
function(c1, c2)
  if c1!.type = c2!.type then 
    return Range(c1) = Range(c2)
           and ForAll(c1!.factored_genpairs,
                      pair -> FIN_CONG_PAIR_IN(c2, pair))
           and ForAll(c2!.factored_genpairs,
                      pair -> FIN_CONG_PAIR_IN(c1, pair));
  fi;
  return Range(c1) = Range(c2) and AsLookupTable(c1) = AsLookupTable(c2);
end);

#TODO do this without AsLookupTable?

InstallMethod(EquivalenceClasses,
"for a finite semigroup congruence by generating pairs rep",
[IsFiniteCongruenceByGeneratingPairsRep],
function(cong)
  local classes, next, tab, elms, i;
  classes := [];
  next := 1;
  tab := AsLookupTable(cong);
  elms := SEMIGROUP_AS_LIST(GenericSemigroupData(Range(cong)));
  for i in [1 .. Size(tab)] do
    if tab[i] = next then
      classes[next] := EquivalenceClassOfElementNC(cong, elms[i]);
      next := next + 1;
    fi;
  od;
  return classes;
end);

  InstallMethod(NonTrivialEquivalenceClasses,
"for a finite semigroup congruence by generating pairs rep",
[IsFiniteCongruenceByGeneratingPairsRep],
function(cong)
  return Filtered(EquivalenceClasses(cong), c -> Size(c) > 1);
end);

InstallMethod(ImagesElm,
"for a finite semigroup congruence by generating pairs rep",
[IsFiniteCongruenceByGeneratingPairsRep,
 IsMultiplicativeElement],
function(cong, elm)
  local lookup, gendata, classNo, elms;
  lookup := AsLookupTable(cong);
  gendata := GenericSemigroupData(Range(cong));
  classNo := lookup[Position(gendata, elm)];
  elms := SEMIGROUP_AS_LIST(gendata);
  return elms{Positions(lookup, classNo)};
end);

SEMIGROUPS.JoinCongruences := function(constructor, c1, c2)
  local pairs, cong, ufdata, uf2, i, ii, next, newtable;
  
  if Range(c1) <> Range(c2) then
    ErrorNoReturn("Semigroups: SEMIGROUPS.JoinCongruences: usage,\n",
                  "congruences must be defined over the same semigroup,");
  fi;

  pairs := Concatenation(ShallowCopy(c1!.genpairs), ShallowCopy(c2!.genpairs));
  cong := constructor(Range(c1), pairs);
  
# TODO redo this!
  # Join the lookup tables
  #if HasAsLookupTable(c1) and HasAsLookupTable(c2) then
  #  # First join the union-find tables
  #  ufdata := UF_COPY(c1!.ufdata);
  #  uf2 := c2!.ufdata;
  #  for i in [1 .. UF_SIZE(uf2)] do
  #    ii := UF_FIND(uf2, i);
  #    if ii <> i then
  #      UF_UNION(ufdata, [i, ii]);
  #    fi;
  #  od;
  #  cong!.ufdata := ufdata;

  #  # Now normalise this as a lookup table
  #  next := 1;
  #  newtable := EmptyPlist(UF_SIZE(ufdata));
  #  for i in [1 .. UF_SIZE(ufdata)] do
  #    ii := UF_FIND(ufdata, i);
  #    if ii = i then
  #      newtable[i] := next;
  #      next := next + 1;
  #    else
  #      newtable[i] := newtable[ii];
  #    fi;
  #  od;
  #  SetAsLookupTable(cong, newtable);
  #fi; # TODO if one or the other does not have the lookup could do TC on 
      # which ever is smaller using the pairs of the other.
  return cong;
end;

InstallMethod(JoinSemigroupCongruences, 
"for finite semigroup (2-sided) congruences by generating pairs rep",
[IsFiniteCongruenceByGeneratingPairsRep and IsSemigroupCongruence, 
 IsFiniteCongruenceByGeneratingPairsRep and IsSemigroupCongruence],
function(c1, c2)
  if c1!.type <> c2!.type or c1!.type <> "twosided" then 
    TryNextMethod(); # FIXME Error?
  elif c1 = c2 then 
    return c1;
  fi;
  return SEMIGROUPS.JoinCongruences(SemigroupCongruence, c1, c2);
end);

InstallMethod(JoinLeftSemigroupCongruences, 
"for finite semigroup (left) congruences by generating pairs rep",
[IsFiniteCongruenceByGeneratingPairsRep and IsLeftSemigroupCongruence, 
 IsFiniteCongruenceByGeneratingPairsRep and IsLeftSemigroupCongruence],
function(c1, c2)
  if c1!.type <> c2!.type or c1!.type <> "left" then 
    TryNextMethod(); # FIXME Error?
  elif c1 = c2 then 
    return c1;
  fi;
  return SEMIGROUPS.JoinCongruences(LeftSemigroupCongruence, c1, c2);
end);

InstallMethod(JoinRightSemigroupCongruences, 
"for finite semigroup (right) congruences by generating pairs rep",
[IsFiniteCongruenceByGeneratingPairsRep and IsRightSemigroupCongruence, 
 IsFiniteCongruenceByGeneratingPairsRep and IsRightSemigroupCongruence],
function(c1, c2)
  if c1!.type <> c2!.type or c1!.type <> "right" then 
    TryNextMethod(); # FIXME Error?
  elif c1 = c2 then 
    return c1;
  fi;
  return SEMIGROUPS.JoinCongruences(RightSemigroupCongruence, c1, c2);
end);
