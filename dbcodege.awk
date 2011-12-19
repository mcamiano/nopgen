# Begin by setting input field seperator to newline,
# and obtaining the list of column names
#
BEGIN { IFS = "\n"
   NumKeyFields = split( "'"$KEYS"'", KeyFields, "," )
   Idx = 0
   while ( "dbcolumn $TABLE" | getline ) {
      ColNum++
      ColName[ ColNum ] = $0
   } 
} 
#
# First rule:  store any lines which fall inside a "PARAGRAPH" frame
#   this is why frames cannot not be nested.
#
/--PARAGRAPH--/, /--END PARAGRAPH--/ { 
   Idx = Idx + 1;
   Para[Idx]=$0;
   for ( ColIdx = 1; ColIdx<=ColNum; ColIdx++ ) {
      CompString = sprintf( "--column%2d--", ColIdx )
      gsub( CompString, ColName[ ColIdx ], Para[Idx] )
   }
   gsub( /--table--/, TableName, Para[Idx] )
   if ( match( Para[Idx], "--END PARAGRAPH--" ) != 0 ) {
      PasteText()
   }
   next;
}
function PasteText() {
    #
    # Following rules:  perform pastes of all "PARAGRAPH" blocks, with edits
    #    This one pastes one frame for each column in the table.
    #
    if ( match( Para[Idx], "--END PARAGRAPH--EACH COLUMN--" ) != 0 ) { 
       for ( ColIdx = 1; ColIdx<=ColNum; ColIdx++ ) {
	  for ( PasteIdx = 1;  PasteIdx <= Idx; PasteIdx++ ) {
	     PasteLine = Para[PasteIdx]
	     gsub( /--column--/, ColName[ ColIdx ], PasteLine )
	     if ( ColIdx == NumKeyFields ) {
		gsub( /--,.*--/, "", PasteLine )  # Comma seperation
	     }
             if ( match( PasteLine, "--PARAGRAPH--" ) == 0 && match( PasteLine, "--END PARAGRAPH--" ) == 0 ) {
                print PasteLine
             }
	  }
       }
       Idx = 0;
       return
    }
    #
    # Following rules:  perform pastes of all "PARAGRAPH" blocks, with edits
    #    This one pastes one frame for each key field in the table.
    #
    if ( match( Para[Idx], "--END PARAGRAPH--EACH KEY FIELD--" ) != 0 ) { 
       for ( ColIdx = 1; ColIdx<=NumKeyFields; ColIdx++ ) {
	  for ( PasteIdx = 1;  PasteIdx <= Idx; PasteIdx++ ) {
	     PasteLine = Para[PasteIdx]
	     gsub( /--column--/, ColName[ ColIdx ], PasteLine )
	     if ( ColIdx == NumKeyFields ) {
		gsub( /--,.*--/, "", PasteLine )  # Comma seperation
	     }
             if ( match( PasteLine, "--PARAGRAPH--" ) == 0 && match( PasteLine, "--END PARAGRAPH--" ) == 0 ) {
                print PasteLine
             }
	  }
        }
        Idx = 0;
        return
     }
}
#
# Next to last rule:  Dump the unedited "PARAGRAPH" block in the garbage.
#
#/--PARAGRAPH--/, /--END PARAGRAPH--/ {
#   next
#}
#
# Last rule:  Print any remaining text out.
#
{
   print $0
}
