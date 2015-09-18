############################################################################
##
#W  congruences/simple.gi
#Y  Copyright (C) 2015                                   Michael C. Torpey
##
##  Licensing information can be found in the README file of this package.
##
#############################################################################
##
## This file contains methods for congruences on finite (0-)simple semigroups,
## using isomorphisms to Rees (0-)matrix semigroups and methods in
## congruences/reesmat.gd/gi.  These functions are not intended for direct
## use by an end-user.
##

InstallGlobalFunction(SEMIGROUPS_SimpleCongFromPairs,
function(s, pairs)
  local iso, r, rmspairs, pcong, rmscong, cong;

  # If s is a RMS/RZMS, then just create the linked triple congruence
  if IsReesMatrixSemigroup(s) then
    # gaplint: ignore 2
    cong := AsRMSCongruenceByLinkedTriple(
            SemigroupCongruenceByGeneratingPairs(s, pairs));
  elif IsReesZeroMatrixSemigroup(s) then
    # gaplint: ignore 2
    cong := AsRZMSCongruenceByLinkedTriple(
            SemigroupCongruenceByGeneratingPairs(s, pairs));
  else
    # Otherwise, create a SIMPLECONG
    iso := IsomorphismReesMatrixSemigroup(s);
    r := Range(iso);
    rmspairs := List(pairs, p -> [p[1] ^ iso, p[2] ^ iso]);
    pcong := SemigroupCongruenceByGeneratingPairs(r, rmspairs);
    if IsReesMatrixSemigroup(r) then
      rmscong := AsRMSCongruenceByLinkedTriple(pcong);
    else  #elif IsReesZeroMatrixSemigroup(r) then
      rmscong := AsRZMSCongruenceByLinkedTriple(pcong);
    fi;
    # Special case for the universal congruence
    if IsUniversalSemigroupCongruence(rmscong) then
      cong := UniversalSemigroupCongruence(s);
    else
      cong := SEMIGROUPS_SimpleCongFromRMSCong(s, rmscong);
    fi;
  fi;
  SetGeneratingPairsOfMagmaCongruence(cong, pairs);
  return cong;
end);

#

InstallGlobalFunction(SEMIGROUPS_SimpleCongFromRMSCong,
function(s, rmscong)
  local iso, r, fam, cong;
  # Find the isomorphism from s to r
  iso := IsomorphismReesMatrixSemigroup(s);
  r := Range(rmscong);

  # Construct the object
  fam := GeneralMappingsFamily(ElementsFamily(FamilyObj(s)),
                               ElementsFamily(FamilyObj(s)));
  cong := Objectify(NewType(fam, SEMIGROUPS_CongSimple),
                    rec(rmscong := rmscong, iso := iso));
  SetSource(cong, s);
  SetRange(cong, s);
  return cong;
end);

#

InstallGlobalFunction(SEMIGROUPS_SimpleClassFromRMSclass,
function(cong, rmsclass)
  local iso, fam, class;
  iso := IsomorphismReesMatrixSemigroup(Range(cong));
  fam := FamilyObj(Range(cong));
  class := Objectify(NewType(fam, SEMIGROUPS_CongClassSimple),
                     rec(rmsclass := rmsclass, iso := iso));
  SetParentAttr(class, cong);
  SetRepresentative(class, Representative(rmsclass) ^
                           InverseGeneralMapping(iso));
  SetEquivalenceClassRelation(class, cong);
  return class;
end);

#

InstallMethod(ViewObj,
"for a (0-)simple semigroup congruence",
[SEMIGROUPS_CongSimple],
function(cong)
  Print("<semigroup congruence over ");
  ViewObj(Range(cong));
  Print(" with linked triple (",
        StructureDescription(cong!.rmscong!.n:short), ",",
        Size(cong!.rmscong!.colBlocks), ",",
        Size(cong!.rmscong!.rowBlocks), ")>");
end);

#

InstallMethod(CongruencesOfSemigroup,
"for a (0-)simple or simple semigroup",
[IsSemigroup],
function(s)
  local R, congs, i;
  if not (IsFinite(s) and (IsSimpleSemigroup(s)
                           or IsZeroSimpleSemigroup(s))) then
    TryNextMethod();
  fi;
  if IsReesMatrixSemigroup(s) or IsReesZeroMatrixSemigroup(s) then
    return CongruencesOfSemigroup(s);
  fi;
  R := Range(IsomorphismReesMatrixSemigroup(s));
  congs := ShallowCopy(CongruencesOfSemigroup(R));
  for i in [1 .. Length(congs)] do
    if IsUniversalSemigroupCongruence(congs[i]) then
      congs[i] := UniversalSemigroupCongruence(s);
    else
      congs[i] := SEMIGROUPS_SimpleCongFromRMSCong(s, congs[i]);
    fi;
  od;
  return congs;
end);

#

InstallMethod(\=,
"for two (0-)simple semigroup congruences",
[SEMIGROUPS_CongSimple, SEMIGROUPS_CongSimple],
function(cong1, cong2)
  return (Range(cong1) = Range(cong2) and cong1!.rmscong = cong2!.rmscong);
end);

#

InstallMethod(JoinMagmaCongruences,
"for two (0-)simple semigroup congruences",
[SEMIGROUPS_CongSimple, SEMIGROUPS_CongSimple],
function(cong1, cong2)
  local join;
  if Range(cong1) <> Range(cong2) then
    Error("Semigroups: JoinMagmaCongruences: usage,\n",
          "<cong1> and <cong2> must be over the same semigroup,");
    return;
  fi;
  join := JoinSemigroupCongruences(cong1!.rmscong, cong2!.rmscong);
  return SEMIGROUPS_SimpleCongFromRMSCong(Range(cong1), join);
end);

#

InstallMethod(MeetMagmaCongruences,
"for two (0-)simple semigroup congruences",
[SEMIGROUPS_CongSimple, SEMIGROUPS_CongSimple],
function(cong1, cong2)
  local meet;
  if Range(cong1) <> Range(cong2) then
    Error("Semigroups: MeetMagmaCongruences: usage,\n",
          "<cong1> and <cong2> must be over the same semigroup,");
    return;
  fi;
  meet := MeetSemigroupCongruences(cong1!.rmscong, cong2!.rmscong);
  return SEMIGROUPS_SimpleCongFromRMSCong(Range(cong1), meet);
end);

#

InstallMethod(\in,
"for an associative element collection and a (0-)simple semigroup congruence",
[IsAssociativeElementCollection, SEMIGROUPS_CongSimple],
function(pair, cong)
  local s;
  # Check for validity
  if Size(pair) <> 2 then
    return false;
  fi;
  s := Range(cong);
  if not ForAll(pair, x -> x in s) then
    return false;
  fi;
  return [pair[1] ^ cong!.iso, pair[2] ^ cong!.iso] in cong!.rmscong;
end);

#

InstallMethod(ImagesElm,
"for a (0-)simple semigroup congruence and an associative element",
[SEMIGROUPS_CongSimple, IsAssociativeElement],
function(cong, elm)
  return List(ImagesElm(cong!.rmscong, elm ^ cong!.iso),
              x -> x ^ InverseGeneralMapping(cong!.iso));
end);

#

InstallMethod(EquivalenceClasses,
"for a (0-)simple semigroup congruence",
[SEMIGROUPS_CongSimple],
function(cong)
  return List(EquivalenceClasses(cong!.rmscong),
              c -> SEMIGROUPS_SimpleClassFromRMSclass(cong, c));
end);

#

InstallMethod(EquivalenceClassOfElement,
"for a (0-)simple semigroup congruence and associative element",
[SEMIGROUPS_CongSimple, IsAssociativeElement],
function(cong, elm)
  if elm in Range(cong) then
    return EquivalenceClassOfElementNC(cong, elm);
  else
    Error("Semigroups: EquivalenceClassOfElement: usage,\n",
          "<elm> must be an element of the range of <cong>");
    return;
  fi;
end);

#

InstallMethod(EquivalenceClassOfElementNC,
"for a (0-)simple semigroup congruence and associative element",
[SEMIGROUPS_CongSimple, IsAssociativeElement],
function(cong, elm)
  local class;
  class := EquivalenceClassOfElementNC(cong!.rmscong, elm ^ cong!.iso);
  return SEMIGROUPS_SimpleClassFromRMSclass(cong, class);
end);

#

InstallMethod(NrCongruenceClasses,
"for a (0-simple) semigroup congruence",
[SEMIGROUPS_CongSimple],
function(cong)
  return NrCongruenceClasses(cong!.rmscong);
end);

#

InstallMethod(\in,
"for an associative element and a (0-)simple semigroup congruence class",
[IsAssociativeElement, SEMIGROUPS_CongClassSimple],
function(elm, class)
  return (elm ^ EquivalenceClassRelation(class)!.iso in class!.rmsclass);
end);

#

InstallMethod(\*,
"for two (0-)simple semigroup congruence classes",
[SEMIGROUPS_CongClassSimple, SEMIGROUPS_CongClassSimple],
function(c1, c2)
  return SEMIGROUPS_SimpleClassFromRMSclass(EquivalenceClassRelation(c1),
                                            c1!.rmsclass * c2!.rmsclass);
end);

#

InstallMethod(Size,
"for a (0-)simple semigroup congruence class",
[SEMIGROUPS_CongClassSimple],
function(class)
  return Size(class!.rmsclass);
end);

#

InstallMethod(\=,
"for two (0-)simple semigroup congruence classes",
[SEMIGROUPS_CongClassSimple, SEMIGROUPS_CongClassSimple],
function(c1, c2)
  return EquivalenceClassRelation(c1) = EquivalenceClassRelation(c2) and
         c1!.rmsclass = c2!.rmsclass;
end);

#

InstallMethod(GeneratingPairsOfMagmaCongruence,
"for a (0-)simple semigroup congruence",
[SEMIGROUPS_CongSimple],
function(cong)
  local map;
  map := InverseGeneralMapping(cong!.iso);
  return List(GeneratingPairsOfMagmaCongruence(cong!.rmscong),
               x -> [x[1] ^ map, x[2] ^ map]);
end);

#

InstallMethod(CanonicalRepresentative,
"for a (0-)simple semigroup congruence class",
[SEMIGROUPS_CongClassSimple],
function(class)
  return CanonicalRepresentative(class!.rmsclass) ^ class!.iso;
end);
