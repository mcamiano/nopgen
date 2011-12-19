:
# dbcodeegen.sh: cookie cutting module maker
#
# No claim is made as to the appropriateness of this software to any task. 
# Use at your own risk. No warranty is expressed or implied.
#
# Utilities used: dbschema, fgrep, egrep, sed, tr, cut
#
# Sugar Free dbcodeegen.sh: No Temp Files; Never had 'em, never will.
#
# Version 1.0
#
# Author: Mitch C. Amiano
#

TABLE="$1"
PATFILE="$2"
KEYS="${3:-1}"              # Default key is field 1 of table
export TABLE PATFILE KEYS

if [ -z "$TABLE" -o "$TABLE" = "-u" -o "$TABLE" = "-usage" \
     -o "$TABLE" = "-help" -o -z "$PATFILE"  ]
then
   more >&2 <<EOT
dbcodegen.sh: generate code given a database table and text pattern file

Usage: dbcodegen.sh tablename patternfile [keyfld1,keyfld2,...keyfldN]
where  tablename  is any table in the current database 
  and  patternfile holds a special text pattern to use for code generation
  and  keyfld1...keyfldN  specifies the primary key of the table in
	  terms of the column positions within the table, in a comma
	  seperated list.

patternfile will contain two special format block types. The first is text
between any --PARAGRAPH-- blocks. Other than global replacement of macros,
it goes untouched throughout processing.

The --PARAGRAPH-- blocks specify frames of text which are generally copied,
cut, and pasted in ways depending on the paragraph type.

The macros are as follows:
   --table--  expands into the table name specified at the command line.
              Used in all text blocks.

   --column-- expands into the current column name in the specified table.
              Only used in the --PARAGRAPH--EACH COLUMN-- block.

   --columnNN-- expands into a specific column name in the specified table.
              Used in all text blocks.

   --,Text--  expands into a comma ( or Text ) in --PARAGRAPH--EACH COLUMN--
	      and --PARAGRAPH--EACH KEY FIELD-- blocks, only if the 
	      current block is not being pasted for the last field name
	      in the column (or key field) list. The "Text" is optional,
              and replaces the comma in the output, but not the written macro.

A patternfile might look like this:

FUNCTION fEdit--table--( l--table-- )
  DEFINE
    l--table-- RECORD LIKE --table--.*
 
  INPUT BY NAME 
--PARAGRAPH--EACH KEY FIELD--
    l--table--.--column-- --,--
--END PARAGRAPH--EACH KEY FIELD--

  WITHOUT DEFAULTS

--PARAGRAPH--EACH KEY FIELD--
  AFTER FIELD --column--
    IF l--table--.--column-- IS NULL THEN
      ERROR --column--, " is empty. "
    END IF  # l--table--.--column-- IS NULL

--END PARAGRAPH--EACH KEY FIELD--

  ON KEY (CONTROL-F)

    CASE   # infield( --table--.* )

--PARAGRAPH--EACH COLUMN--
    WHEN infield( --column-- )
      CALL Pick--column--() RETURNING l2--table--.*
      IF NOT int_flag THEN
        LET l--table--.--column-- = l2--table--.--column--
        DISPLAY BY NAME l--table--.--column--
        NEXT FIELD --column--
      END IF

--END PARAGRAPH--EACH COLUMN--

    END CASE  # infield( --table--.* )

  END INPUT

  RETURN ( l--table--.* )

END FUNCTION   # fSave--table--()


Notes:

 The default primary key is specified as the first, and only the first, field.

 PARAGRAPH blocks are not heirarchical, and cannot be nested.

 System tables are excluded.

 No checking is performed to ensure that "--columnNN--" exists in "--table--".

 The choice of pattern for the macros ( --patern-- ) may not be a good one
 for using with languages like C or C++, since their decrement operator --
 could cause a match to occurr in a normal statement. 

EOT

exit 0

fi

if [ ! -r "$PATFILE" ]
then
   echo "$0: $PATFILE is not readable."
   exit 1
fi

if [ ! -f "$PATFILE" ]
then
   echo "$0: $PATFILE is not a regular file."
   exit 1
fi

cat patfile | sed "s/--table--/$TABLE/g;
s/--\(.*\)\*\(.*\)--/dbcolumn.sh $TABLE \"\1\" \"\2\"/g;" |
awk '
# Begin by setting input field seperator to newline,
# and obtaining the list of column names
#
BEGIN { IFS = "\n"
   NumKeyFields = split( "'"$KEYS"'", KeyFields, "," )
   Idx = 0
   while ( "dbcolumn.sh $TABLE" | getline ) {
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
# 
# This last line, piped through "sed", allows easy global operations.
#    It is easier, with "sed", to do global deletes and replacements.
#
' TableName=$TABLE | sed "s/--,--/,/g; s/--,\(.*\)--/\1/g"
