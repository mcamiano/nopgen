#!sh
TEMPDIR="./tmp"
CATPROG="cat"
DEBUG=1

# Eradicate any 'b.' temp files in the tempdir.

echo "Removing previous 'b.' temporary files from $TEMPDIR." >&2
rm -f "$TEMPDIR/b.*" >&2

FatalError() {

   echo "$*" >&2
   exit -1

}   # End function

Debug() {
   if [ $DEBUG -eq 1 ]
   then 
      echo "Got to $*"
   fi
   return
}   # End function

block() {

   BlockName="$1"

   if [ -z "$BlockName" ]
   then 
      FatalError "block(): BlockName parameter missing"
   fi

   shift

   if [ "$1" ]
   then
      FatalError "block(): extra arguments in statement"
   fi

   while read line
   do
      echo "$line" >> "$TEMPDIR/b.$BlockName"
   done

   return

}   # End function


paste() {

   BlockName="$1"
   Coupling="$2"

   if [ -z "$BlockName" ]
   then 
      FatalError "block(): BlockName parameter missing"
   elif [ ! -f "$TEMPDIR/$BlockName" ]
      FatalError "block(): Text of $BlockName unreadable"
   fi

   if [ -z "$Coupling" ]
   then 
      FatalError "block(): Coupling parameter missing"
   fi

   eval ${$Coupling} | while read line
   do
Debug "Inside while loop: $line" "$TEMPDIR/b.$BlockName"
      SedString=""
      PP=0
      for element in $line
      do
         export PP 
echo $PP
	 PP=`increment $PP`
echo $PP
	 SedString="$SedString s/$PP/$element/g;"
      done
echo "$SedString"
      #sed $SedString $TEMPDIR/b.$BlockName
   done
   
   return

}   # End function

