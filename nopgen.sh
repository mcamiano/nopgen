#!d:/bin/sh.exe
# nop: dependancy factoring system
#
# Copyright 1992 by Mitch C. Amiano.  All Rights Reserved.
#
# No claim is made as to the appropriateness of this software to any task. 
# Use at your own risk. No warranty is expressed or implied.
#
# Utilities used: sh, sed, awk
#
# Version 1.0
#
# Author: Mitch C. Amiano
#
# History: 
#    pre-Sept '92	M.C.Amiano	hacked original version as database
# 			   table dependant code generator/macro processor.
#    9-3-92		begin re-write to make the Awk engine
# 			   independant of source entity interfaces. Add concept
#			   of a "coupling" to online man.  Added seperate cmd
#			   line option for online man page.  Removed
#                          "--table--" macros and made more generic. Decided
#                          to replace "--" in coupling specification with
#                          a user-specified pattern.  Removed "KEYS" variable.
#    9-8-92             Still rewriting.  Renamed to codegen.sh
#                          while modifying. Will probably rename again once 
#                          the thing looks clearer.
#    9-10-92		Doing complete rewrite. Rewriting 
#                          specs by way of online man page.  Split demarcation
#                          pattern into start and stop patterns.
#    9-11-92            Renamed to "nopgen".  Cut out online man pages into
#                          seperate nopgen.man file.
#    9-18-92            Done rewriting specs/man pages. Now rewriting awk
#                          scanning and parsing routines to fit.
#

AWKPROG="gawk"
SEDPROG="sed"
CATPROG="cat"
PRPROG="more"
GREPPROG="egrep"
RMPROG="rm"

PROTOFILES="$*"

if [ -z "$NOPGENHOME" ]
then
   NOPGENHOME="e:/nopgen"
fi

if [ -z "$NOPGENTMP" ]
then
   NOPGENTMP="$NOPGENHOME/tmp"
fi

NOPGENSCRIPT="$NOPGENHOME/nopgen.awk"
MANPAGE="$NOPGENHOME/nopgen.man"

if [ -z "$DEMARCSTART" ] 
then
   DEMARCSTART='$-'
fi
if [ -z "$DEMARCEND" ] 
then
   DEMARCEND='-$'
fi

if [ -z "$JUNCBOXES" ] 
then
   JUNCBOXES="$NOPGENHOME/junction.box"
fi

export PROTOFILES JUNCBOXES DEMARCSTART DEMARCEND 
export NOPGENHOME NOPGENSCRIPT NOPGENTMP
export MANPAGE CATPROG PRPROG AWKPROG SEDPROG RMPROG GREPPROG

#
# Print the online man page if options screwed up or -u option, then exit.
#

if [ -z "$PROTOFILES" -o "$PROTOFILES" = "-u" -o "$PROTOFILES" = "-usage" \
     -o "$PROTOFILES" = "-help" -o -z "$PROTOFILES"  ]
then
   $PRPROG >&2 <<EOT
$0: generate code given a text pattern file and a coupling definition file.

    Copyright 1992 by Mitch C. Amiano.  All Rights Reserved.

Usage: $0 patternfile(s)
where: patternfile holds a special text pattern to use for code generation

   or: $0 [-u|-m]
where  -u brings up this usage message, and -m brings up the online man pages.
EOT

   exit -1
fi

#
# Print the online man page if given the option to do so, then exit.
#

if [ "$PROTOFILES" = "-m" ]
then
   $PRPROG >&2 <$MANPAGE
   exit 0
fi

#
# Check the prototype files for readability
#

FatalError=0
for file in $PROTOFILES
do
   if [ ! -r "$file" ]
   then
      echo "$0: $file is not readable." >&2
      FatalError=1
   fi
   if [ ! -f "$file" ]
   then
      echo "$0: $file is not a regular file." >&2
      FatalError=1
   fi
done

if [ FatalError -eq 1 ]
   exit 1
fi

echo "$0: Removing temporary files in $NOPGENTMP." >&2
$RMPROG -f $NOPGENTMP/* | $GREPPROG -v "Rommel|[Rr]emoved|^ *$" >&2

#
# Edit-out a list of coupling names from the junction box.
#
#COUPLINGS=`$CATPROG $JUNCBOX | $SEDPROG "/[ ]*#.*/d`

$AWKPROG -f $NOPGENSCRIPT        \
   $JUNCBOXES                    \
   $PROTOFILES
