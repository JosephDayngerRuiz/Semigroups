#############################################################################
##
#W  greens.gi
#Y  Copyright (C) 2011                                   James D. Mitchell
##
##  Licensing information can be found in the README file of this package.
##
#############################################################################
##

#############################################################################

# new for 0.1! - \= - "for Green's class and Green's class of trans. semigp."
#############################################################################

InstallMethod(\=, "for Green's class and Green's class of trans. semigp.",
[IsGreensClassOfTransSemigp, IsGreensClassOfTransSemigp],
function(x, y)
  return x!.parent=y!.parent and x!.rep in y and Size(x)=Size(y);
end);

# new for 0.1! - \< - "for Green's class and Green's class of trans. semigp."
#############################################################################

InstallMethod(\<, "for Green's class and Green's class of trans. semigp.", 
[IsGreensClassOfTransSemigp, IsGreensClassOfTransSemigp], ReturnFail);

# new for 0.1! - \= - "for trans. semigp. and trans. semigp."
#############################################################################

InstallMethod(\=, "for trans. semigp. and trans. semigp.",
[IsTransformationSemigroup and HasGeneratorsOfSemigroup, 
IsTransformationSemigroup and HasGeneratorsOfSemigroup],
function(s, t)
  return ForAll(Generators(s), x-> x in t) and 
   ForAll(Generators(t), x-> x in s);
end); 

# mod for 0.4! - \in - "for a transformation semigroup"
#############################################################################
# Notes: not algorithm X. 

InstallMethod(\in, "for a transformation semigroup",
[IsTransformation, IsTransformationSemigroup],
function(f, s)
  local gens, o, data, iter, orbits, images, next;

  if HasAsSSortedList(s) then
    return f in AsSSortedList(s);
  fi;

  gens:=Generators(s);

  if not DegreeOfTransformation(f) = DegreeOfTransformation(gens[1]) then
    Info(InfoCitrus, 2, "trans. has different degree from semigroup.");
    return false;
  fi;

  if not (IsMonoid(s) and IsOne(f)) and RankOfTransformation(f) >
   MaximumList(List(gens, RankOfTransformation)) then
    Info(InfoCitrus, 2, "trans. has larger rank than any element of ",
     "semigroup.");   
    return false;
  fi;
  
  if HasMinimalIdeal(s) and RankOfTransformation(f) <   
   RankOfTransformation(Representative(MinimalIdeal(s))) then
    Info(InfoCitrus, 2, "trans. has smaller rank than any element of ",
     "semigroup."); 
    return false;
  fi;
  
  if HasImagesOfTransSemigroup(s) and not ImageSetOfTransformation(f) in
   ImagesOfTransSemigroup(s) then
    Info(InfoCitrus, 2, "trans. has image that does not occur in ",
     "semigroup");
    return false;
  fi;
  
  if HasKernelsOfTransSemigroup(s) and not CanonicalTransSameKernel(f) in
   KernelsOfTransSemigroup(s) then
    Info(InfoCitrus, 2, "trans. has kernel that does not occur in ", 
     "semigroup");
    return false;
  fi;

  o:=OrbitsOfImages(s); data:=PreInOrbitsOfImages(s, f, false);

  if data[1] then
    return true;
  elif o!.finished then
    return false;
#  elif not HTValue(o!.ht, f)=fail then
#    return true; JDM in lots of places it is assumed after in is called that 
# data of the element is known. With this included the data is not known..
  fi;

  iter:=IteratorOfNewRClassRepsData(s);
  orbits:=o!.orbits; images:=o!.images;

  repeat
    next:=NextIterator(iter);
    if not data[2][2]=fail then
      if next[2]=data[2][2] and next[4]=data[2][4] and (next[5]=data[2][5] or
       data[2][5]=fail) then
        data:=InOrbitsOfImages(f![1], false, data[2], orbits, images);
      fi;
    else 
      data:=InOrbitsOfImages(f![1], false, data[2], orbits, images);
    fi;

    if data[1] then
      return true;
    fi; 
  until IsDoneIterator(iter);

  #JDM could also put something in here that returns false if everything,
  #from OrbitsOfImages(s)!.at to the end of OrbitsOfImages(s)!.ht!.o 
  #has rank less than f. Might be a good idea when degree is very high!

  return false;
end);

#GGG

# new for 0.1! - GreensJClassOfElement - for a trans. semigroup and trans."
#############################################################################

InstallOtherMethod(GreensJClassOfElement, "for a trans. semigroup and trans.",
[IsTransformationSemigroup and HasIsFinite and IsFinite and
HasGeneratorsOfSemigroup, IsTransformation], 
function(s, f)
#  Info(InfoWarning, 2, "Use GreensDClassOfElement instead!");
  return GreensDClassOfElement(s, f);
end);

#III

# new for 0.1! - Idempotents - "for a transformation semigroup"
#############################################################################

InstallOtherMethod(Idempotents, "for a transformation semigroup", 
[IsTransformationSemigroup and HasGeneratorsOfSemigroup],
function(s)
  local n, out, kers, imgs, regular, j, i, ker, img;

  if IsRegularSemigroup(s) then 
    n:=DegreeOfTransformationSemigroup(s);

    if HasNrIdempotents(s) then 
      out:=EmptyPlist(NrIdempotents(s));
    else
      out:=[];
    fi;

    kers:=GradedKernelsOfTransSemigroup(s); 
    imgs:=GradedImagesOfTransSemigroup(s);

    regular:=false; 

    if HasIsRegularSemigroup(s) and IsRegularSemigroup(s) then 
     regular:=true;
    fi;

    j:=0;
    
    for i in [1..n] do
      for ker in kers[i] do
        for img in imgs[i] do 
          if IsInjectiveTransOnList(ker, img) then 
            j:=j+1;
            out[j]:=IdempotentNC(ker, img);
          fi;
        od;
      od;
    od;

    if not HasNrIdempotents(s) then 
      SetNrIdempotents(s, j);
    fi;
    return out;
  fi;

  return Concatenation(List(GreensRClasses(s), Idempotents));
end);

# new for 0.1! - Idempotents - "for a trans. semigroup and pos. int."
####################################################################################

InstallOtherMethod(Idempotents, "for a trans. semigroup and pos. int.", 
[IsTransformationSemigroup and HasGeneratorsOfSemigroup, IsPosInt],
function(s, i)
  local out, n, kers, imgs, j, ker, img, r;
  
  n:=DegreeOfTransformationSemigroup(s);
  
  if i>n then 
    return [];
  fi;

  if HasIdempotents(s) then 
    return Filtered(Idempotents(s), x-> RankOfTransformation(x)=i);
  fi; 

  if HasNrIdempotents(s) then
    out:=EmptyPlist(NrIdempotents(s));
  else
    out:=[];
  fi;

  if IsRegularSemigroup(s) then 

    kers:=GradedKernelsOfTransSemigroup(s)[i]; 
    imgs:=GradedImagesOfTransSemigroup(s)[i];
    j:=0;

    for ker in kers do
      for img in imgs do 
        if IsInjectiveTransOnList(ker, img) then 
          j:=j+1;
          out[j]:=IdempotentNC(ker, img);
        fi;
      od;
    od;

    return out;
  fi;

  for r in GreensRClasses(s) do 
    if RankOfTransformation(r!.rep)=i then 
      out:=Concatenation(out, Idempotents(r));
    fi;
  od;
  return out;
end);

# new for 0.1! - IsGreensClassOfTransSemigp - "for a Green's class"
#############################################################################

InstallMethod(IsGreensClassOfTransSemigp, "for a Green's class",
[IsGreensClass], x-> IsTransformationSemigroup(ParentAttr(x)));

# new for 0.1! - IsGreensClass - "for a Green's class"
#############################################################################

InstallOtherMethod(IsGreensClass, "for an object", [IsObject], ReturnFalse);
InstallOtherMethod(IsGreensRClass, "for an object", [IsObject], ReturnFalse);
InstallOtherMethod(IsGreensLClass, "for an object", [IsObject], ReturnFalse);
InstallOtherMethod(IsGreensHClass, "for an object", [IsObject], ReturnFalse);
InstallOtherMethod(IsGreensDClass, "for an object", [IsObject], ReturnFalse);

# new for 0.2! - Iterator - "for a trivial trans. semigp."
#############################################################################
# Notes: required until Enumerator for a trans. semigp does not call iterator. 
# This works but is maybe not the best!

InstallOtherMethod(Iterator, "for a trivial trans. semigp", 
[IsTransformationSemigroup and HasGeneratorsOfSemigroup and IsTrivial], 9999,
function(s)
  return TrivialIterator(GreensRClassReps(s)[1]);
end);

#NNN

# new for 0.1! - NrIdempotents - "for a transformation semigroup"
#############################################################################

InstallMethod(NrIdempotents, "for a transformation semigroup", 
[IsTransformationSemigroup and HasGeneratorsOfSemigroup],
function(s)
  local i, iter, d;
  
  i:=0;

  if HasIdempotents(s) then 
    return Length(Idempotents(s));
  fi;

  if OrbitsOfKernels(s)!.finished and HasGreensDClasses(s) then 
    for d in GreensDClasses(s) do 
      i:=i+NrIdempotents(d);
    od;
  else
    iter:=IteratorOfRClassRepsData(s);
    for d in iter do 
      i:=i+NrIdempotentsRClassFromData(s, d);
    od;
  fi;

  return i;
end);

# new for 0.1! - NrGreensHClasses - "for a transformation semigroup"
#############################################################################
 
InstallMethod(NrGreensHClasses, "for a transformation semigroup", 
[IsTransformationSemigroup and HasGeneratorsOfSemigroup],
function(s)
  local i, iter, o, d;
  i:=0;

  iter:=IteratorOfDClassRepsData(s);
  o:=[OrbitsOfImages(s), OrbitsOfKernels(s)];

  for d in iter do 
    i:=i+Length(ImageOrbitCosetsFromData(s, d[2], o[2]))*
     Length(ImageOrbitSCCFromData(s, d[1], o[1]))*
      Length(KernelOrbitSCCFromData(s, d[2], o[2]))*
       Length(KernelOrbitCosetsFromData(s, d[2], o[2]));
  od;

  return i;
end);

# new for 0.1! - UnderlyingSemigroupOfIterator - "for a citrus pkg iterator"
#############################################################################

InstallGlobalFunction(UnderlyingSemigroupOfIterator, 
[IsCitrusPkgIterator], iter-> iter!.s);

#EOF
