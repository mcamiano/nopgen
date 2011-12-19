# NOpGen.Awk program to generate code.
# Copyright 1992 by Mitch C. Amiano
# All Rights Reserved.
# No claim is made as to the appropriateness of this software to any task.
# Use at your own risk. 
# No warranty is expressed or implied.
#
# Note: Since Awk scripts are interpreted, not compiled, the input interface
#       is determined by the runtime invocation. So the interface this program
#       expects is documented below.
#
# Input interface:   ( Read in as arguments, in the following order. )
#
#   junctionfile1 junctionfile2... junctionfileN
#   protofile1 protofile1... protofileN
#
# Output interface: stdout
#
# Legend of Regular Expresions:
#
# [cC][oO][uU][pP][lL][iI][nN][gG]   the word "coupling"
# [ \t]*                             zero or more whitespace characters
# [a-zA-Z0-9_]+                      a legal identifier (at least one char)
# .*                                 any (or no) characters
#
# History: 
#   Pre-September, 1992	Developed ideas of information-repository/data-dictionary/
#			info-server based source code manipulation.  Wrote paper
#			describing ideas of defining software in terms of the 
#			inter- and infra- system dependancies.  Researched and
#			disqualified several approaches, including cpp macros, m4
#			macros, sed editing scripts, Makefiles, and shell based
#			code generators for Informix-4GL.
#   September, 1992	Prototyped as dbgenr.sh, then dbcodegen.awk.
#			Developed idea for seperate pattern text and specializing text.
#			Block-orientation is evident even in this prototype, but
#			PARAGRAPHs (blocks) do not have parameters or names, and
#			cannot be reused by independant PASTE statements.  Also,
#			couplings are not independant reusable entities.
#   October 6, 1992	Changed names several times, re-prototyped as Bourne-shell 
# 			only script.  Increased use of temp directory and distinct files for
#   October 18, 1992	block storage.  Discarded idea of shell-only script. Two-tiered
#			program - 1 shell integration script, and 1 awk workhorse pgm.
#			Seperated coupling definitions into 'junction' file, while retaining
#			ability to define within pattern files.  NOpGen editing language
#			is essentially codified, with the specification roughed out in the
#			document "nopgen.man".  "depend.doc" is written to codify
#			ideas regarding the abstract aspects.
#			Name is finalized as NOpGen (Northside Operations Generator).
#   December 12, 1992	Various infrequent debugging to this point. Major mistakes
#			marked off with the word Defect in a comment.  Major milestone
#			reached, in that NOpGen accepted all sample input and produced 
#			BLOCK temporary files without a single fatal error. Unfortunately,
#			still doesn't give FULLTEXT block output correctly.
#   December 19, 1992	Changing DEMARC handling to eliminate incorrect 
#			handling of RE's by HandleText().
#   December 20, 1992	Further Reg Exp defects being fixed.
#   				

# Action 1: Initialize program before input.

# Beginnings:
#  1. Import the demarcation RE's.
#  2. Calculate and store the size of the demarcation RE's.
#     This is so that they can be removed from statements and text.
#  3. Set up some generally useful regular expressions.

BEGIN { IFS = "\n"

# Set up Environmental globals 

   GetEnvVars()

# RegExp patterns used to successively tear apart text into Nopgen statements.

   WHITESPACE_RE="[ \t]*"
   PARSE_RE="^.*" DEMARCSTART_RE "|" DEMARCEND_RE ".*" DEMARCSTART_RE "|" DEMARCEND_RE ".*$"
   PRETEXT_RE="^.+" DEMARCSTART_RE
   NOTPRETEXT_RE=DEMARCSTART_RE "|$"
   #STATEMENT_RE=PRETEXT_RE ".*" DEMARCEND_RE ".*$"
   COMMAND_RE=DEMARCSTART_RE ".*" DEMARCEND_RE

# RegExp patterns used to parse Nopgen statements themselves.

   BLOCK_RE= "^[ \t]*[Bb][Ll][Oo][Cc][Kk][ \t]+"
   ENDBLOCK_RE= "^[ \t]*[Ee][Nn][Dd][ \t]*[Bb][Ll][Oo][Cc][Kk][ \t]*" WHITESPACE_RE
   EVALUATE_RE="^[ \t]*[Ee][Vv][Aa][Ll][Uu][Aa][Tt][Ee][ \t]+" 
   SIMPLECOUP_RE= "^[ \t]*[a-zA-Z0-9_]+[ \t]*$"  
   PASTE_RE= "^[ \t]*[Pp][Aa][Ss][Tt][Ee][ \t]+" 
   COUPLING_RE= "^[ \t]*[cC][oO][uU][pP][lL][iI][nN][gG][ \t]+" 
   COMMENT_RE="^[(].*[)]$"

   BLOCKNAME_RE="[ \t]*[a-zA-Z0-9_]+" 
   PARAMLIST_RE="[ \t]*[(]([ \t]*[^ \t)]+[ \t]*)*[)][ \t]*"
   PARAMS_RE="([ \t]*[^ ()\t]+[ \t]*)*"
   PARAMS_SEPER_RE="[ \t]*,[ \t]*"
   PARAMS_DFLT_RE="[ \t]*=[ \t]*\"[^ \t]+\"[ \t]*"
   UNLESSNULL_RE="[ \t]*[Uu][Nn][Ll][Ee][Ss][Ss][ \t]*[Nn][Uu][Ll][Ll][ \t]*"

   COUPRESULTS_SEPER_RE="[ \t]*"

# Nopgen program state constants.

   NOPGEN_READING=1   
   NOPGEN_WRITING=2
   NOPGEN_FATAL=-1
   
# Nopgen program state variables.

   NopgenState=NOPGEN_READING
   CurrentBlock="fulltext"       # Used to process blocks of text.

   # NumBlockParams[]            # Holds count of block parameters
   # BlockParameter[]            # Holds most current value of BLOCKs' parameters
   # BlockDefaults[]             # Holds BLOCKs' parameter defaults, most null
   # Coupling[]                  # Holds name of couplings

# Program Initiation Activity

                                 # Open first temp file for "fulltext".
   OpenTempFile( TEMP_DIRECTORY, CurrentBlock )
}

# Action 2: Read text from the pattern files.

NopgenState == NOPGEN_READING {

   ProcessLines( $0 )

}   # End action


# Action 3: Process for output

END {
Debug( "END: Preparing to process output" )

   if ( NopgenState == NOPGEN_FATAL ) {   # Fatal error detected earlier.
      exit 
   }
   else {

      NopgenState=NOPGEN_WRITING

      ProcessOutput()

   }
}


# ProcessOutput():  store it or forward for more processing.
#
# Variables:

function ProcessOutput(      CommandLine )   {
Debug( "ProcessOutput(" )

   CommandLine = sprintf( "cat %s/fulltext", TEMP_DIRECTORY  )

# Loop through lines in "fulltext", evaluating the output.

   close( TEMPFILE )

   while ( CommandLine | getline LastPassText ) {
      ProcessLines( LastPassText )
   }

   return

}   # End function


# ProcessLines():  store it or forward for more processing.
#
# Variables:
#   Stuff   (local parameter)
#   STATEMENT_RE   (global constant)

function ProcessLines( Stuff )   {
Debug( "ProcessLines(" )

# Check line for pattern characteristic of a nopgen statement.

   if ( match( Stuff, COMMAND_RE ) == 0 ) {   # No match

      HandleText( Stuff, "yes" ) 

   }
   else {                                 # It has a statement inside it
                                          # Figure out which one(s)
      ParseTextLine( Stuff )
   }

   return

}   # End function

# ParseTextLine():  parse text-embeded statement into commands and text.
#
# Variables:
#    TextLine   (local parameter)
#    PretextPos   (local)
#    PretextLength   (local)
#    Pretext   (local)
#    RLENGTH   (Environment State)
#    PRETEXT_RE   (global constant)
#    STARTDM_LENGTH   (global constant)
#    ENDDM_LENGTH   (global constant)
#    COMMAND_RE   (global constant)
#    CommandPos   (local)
#    CommandLength   (local)
#    Command   (local)

function ParseTextLine( TextLine,
   PretextPos, PretextLength, Pretext,
   CommandPos, CommandLength, Command ) {

Debug( "ParseTextLine(" )
   while( length( TextLine ) > 0 )  {              # Continue until used up
Debug( "TextLine:" TextLine )

# Cut and paste any leading non-statement text.

      PretextPos=match( TextLine, NOTPRETEXT_RE )
Debug( "NOTPretextPos:" PretextPos )

      if ( PretextPos > 1 ) {                         # Leading text found

	 PretextLength=PretextPos-1
	 Pretext=substr( TextLine, 1, PretextLength )
Debug( "PreText:"  Pretext )

	 TextLine = substr( TextLine, PretextPos )

	 HandleText( Pretext, "no" )                  # Stored w/out newline

      }   # End if

# The next part must be text within demarcation strings.
# It could also have more trailing text and statements intermixed.

# Parse and cut out the command.  Then case it.

      CommandPos=match( TextLine, DEMARCSTART_RE ) 

Debug( "CommandPos:"  CommandPos )

      if ( CommandPos >= 1 ) {    # Command found in remainder
                                  # Cut out the command, removing demarcations.

                                  # Length here includes demarcations.

         CommandLength=CommandPos + match( TextLine, DEMARCEND_RE )
            + ENDDM_LENGTH

Debug( "CommandLength:"  CommandLength )

                                  # Get the actual command text

         Command=substr( TextLine, CommandPos + STARTDM_LENGTH, 
            CommandLength - (STARTDM_LENGTH + ENDDM_LENGTH))

Debug( "Command:"  Command )

            # Cut the command out of line, with demarcation strings.

         TextLine = substr( TextLine, CommandLength+1 ) 

Debug( "TextLine:"  TextLine )

         CaseCommand( Command )      # Dispatch the proper functions.

      }   # End if

   }   # End while

   HandleText( "", "yes" )       # Force increment of line in temp file.

}   # End function

# HandleText():  Store text in temp file for output later.
#
# Variables:
#   TextLine   (local parameter)
#   Increment   (local parameter)

function HandleText( TextLine, Increment ) {
Debug( "HandleText(" TextLine )


# Throw the text into the temp file.
   
   if ( NopgenState == NOPGEN_READING ) {

      if ( Increment != "no" ) {
	 printf( "%s\n", TextLine ) >> TEMPFILE
      }
      else {
	 printf( "%s", TextLine ) >> TEMPFILE
      }

   }
   else {

      if ( NopgenState == NOPGEN_WRITING ) {
	 if ( Increment != "no" ) {
	    printf( "%s\n", TextLine ) 
	 }
	 else {
	    printf( "%s", TextLine )
	 }
      }
   }

   return

}   # End function

# CaseCommand():  Dispatch a command string.
#
# Variables:
#   stmnt  (local parameter)
#   

function CaseCommand( stmnt ) {
Debug( "CaseCommand(" )

# Action: Comments (anything within demarcations and immediate parenthesis).
# Note that a comment must not have any characters between the parens and
# the demarcation strings.

   if ( stmnt ~ COMMENT_RE ) {                     # Do action in any state.
Debug( "Case: Comment" )
      # Do nothing at all for comments.
      # This way, the comment is effectively 'cut' from the output.
      return
   }

# BLOCK statements.               Apply to any state.
# Defect: End Block phrase not matched.

   if ( stmnt ~ BLOCK_RE ) {
Debug( "Case: Begin Block" )
      StartStoringBlock( stmnt )
      return
   }

# END BLOCK statements.           Apply to any state.

   if ( stmnt  ~ ENDBLOCK_RE ) {
Debug( "Case: End Block" )
      EndStoringBlock( stmnt )
      return
   }

# Action: EVALUATE statements.            Do only in output state.

   if ( stmnt ~  EVALUATE_RE )  {

      if ( NopgenState == NOPGEN_WRITING )  {
Debug( "Case: Evaluate" )
	 EvalEvaluate( stmnt )
	 return
      }
      else {   # Replace it in its pristine form.
	 HandleText( DEMARCSTART_STRING, "no" )      # Stored w/out newline
	 HandleText( stmnt, "no" )                  # Stored w/out newline
	 HandleText( DEMARCEND_STRING, "no" )      # Stored w/out newline
	 return
      }
   }

# PASTE statement.                 Only in output state.

   if ( stmnt ~ PASTE_RE )  {

      if ( NopgenState == NOPGEN_WRITING )  {
Debug( "Case: Paste" )
	 PasteBlock( stmnt )
	 return
      }
      else {   # Replace it in its pristine form.
	 HandleText( DEMARCSTART_STRING, "no" )         # Stored w/out newline
	 HandleText( stmnt, "no" )                    # Stored w/out newline
	 HandleText( DEMARCEND_STRING, "no" )       # Stored w/out newline
	 return
      }
   }

# COUPLING definition statements.   Only in output state.

   if ( stmnt ~ COUPLING_RE )  {

      if ( NopgenState == NOPGEN_WRITING )  {
   
Debug( "Case: Coupling Definition" )
	 EvalCoupDef( stmnt )
	 return
      }
      else {   # Replace it in its pristine form.
	 HandleText( DEMARCSTART_STRING, "no" )         # Stored w/out newline
	 HandleText( stmnt, "no" )                     # Stored w/out newline
	 HandleText( DEMARCEND_STRING, "no" )         # Stored w/out newline
	 return
      }
   }

# Final case matches a simple coupling to be evaluated inline.
# Output state only.

   if ( stmnt ~ SIMPLECOUP_RE )  {

      if ( NopgenState == NOPGEN_WRITING )  {
   
Debug( "Case: Simple Coupling" )
	 EvalSimpleCoup( stmnt )
	 return
      }
      else {       # replace it in its pristine form
	 HandleText( DEMARCSTART_STRING, "no" )      # Stored w/out newline
	 HandleText( stmnt, "no" )                  # Stored w/out newline
	 HandleText( DEMARCEND_STRING, "no" )      # Stored w/out newline
	 return
      }
   }

Debug( "Case: Default (nothing matched)" )
   return

}   # End function

# EvalEvaluate():  Evaluate a coupling recursively
#
# Variables:
#   stmnt   (local parameter)
#   coup    (local)
#   TextFile   (local)
#   Params   (local)
#   EvalId   (local)
#   TEMP_DIRECTORY   (global constant)
#   CommandLine   (local)
#   TextLine   (local)

function EvalEvaluate( stmnt, coup, TextFile, Params, EvalId, CommandLine,
TextLine, CoupPos,  CoupLen, CoupStr, EvalPos, EvalLen, EvalStr,
TempParamNum, TempBufIdx, TempName, ParamLine ) { 

Debug( "EvalEvaluate(" )
# Increment EvalId to identify current EVALUATE statement and temp file.

   EvalId += 1

# Parse statement into command line and parameters.

# Remove the EVALUATE keyword to simplify parsing.

   stmnt=CutRE( EVALUATE_RE, stmnt )

# Copy and cut out coupling name.

   CoupStr=CopyRE( COUPLING_RE, stmnt )
   stmnt=CutRE( COUPLING_RE, stmnt)

# Copy and store coupling parameters in Params
   stmnt=CutRE( "^[ \t]*[(]",  stmnt )
   stmnt=CutRE( "[)][ \t]*$",  stmnt )
   TempParamNum = split( stmnt, Params, PARAMS_SEPER_RE )

# Loop through each coupling parameter and create line of parameters' values

   ParamLine=""
   for ( TempBufIdx=1; TempBufIdx <= TempParamNum;  ++TempBufIdx ) {

      TempName = CurrentBlock TempParamBuf[ TempBufIdx ]

      if ( TempName in BlockParameter ) {
         ParamLine = ParamLine BlockParameter[ TempName ]
      }
      else {
         ParamLine = "Evaluating couple parameters: " ParamLine 
         FatalError( ParamLine )

      }   # End if

   }   # End for

# Create temporary file for evaluation text storage.
# Better to keep it in temp file because EVALUATE recursion could 
# overflow the program's limits.

   TextFile = sprintf( "%s/evaluate.%d", TEMP_DIRECTORY,  EvalId )

# Create a command line to execute the coupling.

   CommandLine=Coupling[ CoupStr ] " " ParamLine " >> " TextFile

# Execute the command line. It is a fatal error if it fails.

   if ( system( CommandLine ) == -1 ) {       # Unexpected error
      CommandLine=" Evaluating couple: " CommandLine
      FatalError( CommandLine )
   }

# Then recycle the lines obtained through nopgen.

   CommandLine = sprintf( "cat %s", TextFile )

   while ( CommandLine | getline TextLine ) {
      ProcessOutput( TextLine )
   }

   return

}   # End function

# StartStoringBlock():  Initialize block recording and state.
#
# Variables:
#   BlockCmd    (local parameter)
#   CurrentBlock   (global variable)
#   Blkname   (local)
#   TEMP_DIRECTORY   (global constant)
#   BlockParameter[]   (global buffer)
#   TempParamBuf[]   (local buffer)
#   TempParamNum     (local)
#   TempDfltVal      (local)
#   TempBufIdx       (local)

function StartStoringBlock( BlockCmd,       Blkname, TempParamBuf, TempParamNum, TempDfltVal, TempBufIdx ) {
Debug( "StartStoringBlock(" )

# Validate the program state.

   if ( CurrentBlock != "fulltext" ) {          # Illegal Nesting Error

      FatalError( " generating text.  Illegal nesting of BLOCKs." )

   }
   else {                        # Start recording the current block.

# Cut out the BLOCK keyword.

      BlockCmd = CutRE( BLOCK_RE, BlockCmd )
Debug(  BlockCmd )

# Parse out the block name into Blkname. The validate it.

      Blkname = CopyRE( BLOCKNAME_RE, BlockCmd )
Debug(  Blkname )

      if ( length( Blkname ) == 0 ) {
         FatalError( "StartStoringBlock(): no block name given." )
      }
      else {
         if ( Blkname == "fulltext" ) {
	    FatalError( "StartStoringBlock(): invalid block name given." )
	 }
      }

# Set the current block to be that of this block name.

      CurrentBlock=Blkname

# Parse out the optional block parameters into BlockParameter[]
# The index for BlockParameter is mangled from Blkname+"parametername"
# The values for the parameters are the actual values of the array.

      BlockCmd = CopyRE( PARAMLIST_RE, BlockCmd )

#Defect: syntax err in RE due to literal parenthesis

      BlockCmd=CopyRE( PARAMS_RE,  BlockCmd )

      TempParamNum = split( BlockCmd, TempParamBuf, PARAMS_SEPER_RE )
      NumBlockParams[ CurrentBlock ] = TempParamNum

# At this point, TempParamBuf may contain nothing, or parameters
# with default assignments.  Any default assignments have to be sorted out.

      for ( TempBufIdx=1; TempBufIdx <= TempParamNum; ++TempBufIdx ) {

	 if ( TempParamBuf[ TempBufIdx ]  ~ PARAMS_DFLT_RE ) {
# Defaults exist.

# Copy default value out, and snip off any leading/trailing junk.

	    TempDfltVal = CopyRE( PARAMS_DFLT_RE, TempParamBuf[ TempBufIdx ] )
	    TempDfltVal = CutRE( "^[ \t]*=[ \t]*\"", TempDfltVal )
	    TempDfltVal = CutRE( "\"[ \t]*$", TempDfltVal )

# Assign default value to BlockParameter[]. Re-use Blkname local variable.

	    Blkname = Blkname TempParamBuf[ TempBufIdx ]

	    BlockParameter[ Blkname ] = TempDfltVal
	    BlockDefaults[ Blkname ] = TempDfltVal
	 }
	 else {       # Default does not exist. Initialize to null.

	    Blkname = Blkname TempParamBuf[ TempBufIdx ]

	    BlockParameter[ Blkname ] = ""
	    BlockDefaults[ Blkname ] = ""

	 }   # End if

      }   # End for

# If the block has been defined already, it will be appended to.
# Open the temp file associated with the block.

      OpenTempFile( TEMP_DIRECTORY, CurrentBlock )
   }

   return

}   # End function

# OpenTempFile():  Open a file for block recording.
#
# Variables:
#   Dir   (local parameter)
#   FileName   (local parameter)
#   TEMPFILE   (global variable)

function OpenTempFile( Dir, FileName ) { 
Debug( "OpenTempFile(" )

# Create temp file name from temp dir and block name.

   TEMPFILE = sprintf( "%s/%s", Dir, FileName )

   printf( "" ) >> TEMPFILE

   return

}   # End function

# EndStoringBlock():  Finalize block recording and state.
#
# Variables:
#   BlockCmd   (local parameter)
#   CurrentBlock   (global variable)
#   TEMPFILE   (global variable)
#   TEMP_DIRECTORY    (global constant)

function EndStoringBlock( BlockCmd ) {
Debug( "EndStoringBlock(" )

# Validate program state.

   if ( CurrentBlock == "fulltext" ) {

      FatalError( "EndStoringBlock(): Unmatched END BLOCK statement." )

   }
   else {                         # Stop recording the current block.

      close( TEMPFILE )

      CurrentBlock="fulltext"

      OpenTempFile( TEMP_DIRECTORY, CurrentBlock )
   }

   return

}   # End function

# PasteBlock():  Copy a previously recorded block into current block.
#
# Variables:
#   PasteCmd   (local parameter)
#   Blkname   (local)
#   coup   (local)
#   CoupParams[]   (local)
#   BlockParameter[]   (global buffer)

function PasteBlock( PasteCmd, Blkname, BlockParamIdx, Coup, CoupParams, CoupParamLine, NumCoupParams, CoupParamsIdx, FieldSpecLine, FieldSpecs, NumFieldSpecs, FieldSpecsIdx, CommandLine, CommandLine2, BlockText, UnlessNull, ResultFields, NumResultFields  ) {
Debug( "PasteBlock(" )

# Validate the statement while parsing it.

# Cut out the PASTE keyword.

      PasteCmd = CutRE( PASTE_RE, PasteCmd )

# Parse out the block name into Blkname.

      Blkname = CopyRE( BLOCKNAME_RE, PasteCmd )

# Validate the block name. If it doesn't exist, it's a fatal error.

      if ( length( Blkname ) == 0 ) {
         FatalError( "PasteBlock(): no block name given." )
      }
      else {
         if ( ValidBlock( Blkname ) == 0 ) {   # Invalid block
	    FatalError( "PasteBlock(): block name given is not defined." )
         }
      }

# Cut out the block name

   PasteCmd = CutRE( BLOCKNAME_RE, PasteCmd )

# Parse out the coupling field specifiers.
# No validation is needed for field specifiers.
# The fields are used to read values from the coupling stream positionally.
# They should correspond to block parameters somewhere along the PASTE
# heirarchy.  After this PASTE is done, they are tossed into the bit bucket.
# The index for BlockParameter is mangled from Blkname+"parametername"

   FieldSpecLine = CopyRE( PARAMLIST_RE, PasteCmd )
   FieldSpecLine = CutRE( "^[ \t]*[(]",  PasteCmd )
   FieldSpecLine = CutRE( "[)][ \t]*$",  PasteCmd )

# If the number of fields is zero, the paste is done without any reference
#    to the actual values returned by the coupling.  This allows a straight
#    copy operation;  the number of copies done corresponds to the number
#    of fields returned by the coupling.

   NumFieldSpecs = split( PasteCmd, FieldSpecs, PARAMS_SEPER_RE )

# If there are more field specifiers than Block parameters,
#    it is not so-good, but not a fatal error either. The extra parameter
#    specifiers in the command line will be ignored.

# Cut out field specifiers from paste command line.
#leftoff
   PasteCmd = CutRE( FieldSpecLine, PasteCmd )

# The field specifiers are now prepared and contained in FieldSpecs[],
#    which is indexed by its ordinal number.


# Parse out the coupling name into coup.

   Coup = CopyRE( COUPLING_RE, PasteCmd )

   PasteCmd = CutRE( Coup, PasteCmd )

# Validate the coupling. If it doesn't exist, the heck with it. It's a comment.

   if ( Coup in Coupling ) {

# Parse out the coupling parameters into CoupParams[], indexed by param name.
# The coupling parameters are considered to be variables defined in a 
# previous PASTE operation, as part of a coupling-field-specifier-list,
# or from default BLOCK parameters.

      CoupParamsLine = CopyRE( PARAMLIST_RE, PasteCmd )
      CoupParamsLine = CutRE( "^[ \t]*[(]", CoupParamsLine )
      CoupParamsLine = CutRE( "[)][ \t]*$", CoupParamsLine )
      PasteCmd = CutRE( CoupParamsLine, PasteCmd )

      NumCoupParams = split( CoupParamsLine, CoupParams, PARAMS_SEPER_RE )

# Validate the coupling parameters.  If they are not assigned in a 
#   previous or current block, then it is a fatal error.

      CommandLine = Coupling[ Coup ]

      for ( CoupParamsIdx = 1; CoupParamsIdx <= NumCoupParams; ++CoupParamsIdx ) {

	 BlockParamIdx = CurrentBlock CoupParams[ CoupParamsIdx ]

	 if ( BlockParamIdx in BlockParameter ) {
	     CommandLine = CommandLine " " BlockParameter[ BlockParamIdx ]
	 }
	 else {
	    PasteCmd = "Undefined coupling parameter: " BlockParamIdx
	    FatalError( PasteCmd )
	 }   # End if

      }   # End for

# Check for the UNLESS NULL clause, which specifies that the paste operation
#   will evaluate to nothing if no coupling fields are returned.

      UnlessNull = match ( PasteCmd, UNLESSNULL_RE ) 

# Now, process the coupling and copy the block for each space-delineated field.

      while ( CommandLine | getline Results  ) {

# chop the coupling output results apart into component fields

	 NumResultFields = split( Results, ResultFields, COUPRESULTS_SEPER_RE )

# Check to see if the line is null or only a remainder with only a few fields 

	 if (( (NumResultFields < NumFieldSpecs) && (UnlessNull > 0) ) || (NumResultFields >= NumFieldSpecs) ) {

# Assign field values to BlockParams to be used when substituting.
# Initialize unassigned BlockParameter[] values to defaults (BlockDefaults[])

	    for ( CoupParamsIdx = 1; CoupParamsIdx <= NumBlockParams[ Blkname ]; ++CoupParams ) {

	       if ( CoupParamsIdx <= NumResultFields ) {
		  BlockParamIdx = Blkname CoupParams[ CoupParamsIdx ]
		  BlockParameter[ BlockParamIdx ] = ResultFields[ CoupParamsIdx ]
	       }
	       else {
		  BlockParamIdx = Blkname CoupParams[ CoupParamsIdx ]
		  BlockParameter[ BlockParamIdx ] = BlockDefaults[ CoupParamsIdx ]
	       }

	    }   # End if

# We have:   
#            TEMP_DIRECTORY/Blkname
#            BlockParameter[ Blkname + Parmname ]

# Loop through text line which was stored previously for this block

	    CommandLine2 = sprintf( "cat %s/%s", TEMP_DIRECTORY, CurrentBlock )

	    while ( CommandLine2 | getline BlockText ) {

# Loop through each block parameter, and global substitute on the new line

	       for ( CoupParamsIdx = 1;  CoupParamsIdx <= NumBlockParams[ Blkname ]; ++CoupParams ) {
		  BlockParamIdx = Blkname CoupParams[ CoupParamsIdx ]
		  gsub( CoupParams[ CoupParamsIdx ], BlockParameter[ BlockParamIdx ], BlockText )
	       }

# Last leg: send the line out.

	       HandleText( BlockText, "yes" )

	    }   # End while

	 }   # End if

      }   # End while

   }   # End if

   return

}   # End function

# EvalSimpleCoup():  evaluate a simple coupling and include its text
#
# Variables:
#   coup   (local parameter)
#   InputText   (local)

function EvalSimpleCoup( coup,      InputText ) {
Debug( "EvalSimpleCoup(" )

   while ( Coupling[ coup ] | getline InputText ) {
      HandleText( InputText, "yes" )
   }

   return

}   # End function

# EvalCoupDef():  parse line of coupling definition and store it.
#
# Variables:
#   TextLine   (local parameter)
#   TempSplit  (local temporary)
#   CoupName   (local temporary)
#   CoupDefStart   (local temporary)
#   Coupling   (global buffer array)

function EvalCoupDef( TextLine,      TempSplit, CoupName, CoupDefStart ) {
Debug( "EvalCoupDef(" )

# Address the following actions to coupling definitions only.
#  The form of the definition is:   coupling coupname = "stuff"

   if ( TextLine ~ /^[ \t]*[cC][oO][uU][pP][lL][iI][nN][gG][ \t]*[a-zA-Z0-9_]+[ \t]*=[ \t]*".*"[ \t]*$/ || TextLine ~ /^[ \t]*[cC][oO][uU][pP][lL][iI][nN][gG][ \t]*[a-zA-Z0-9_]+[ \t]*=[ \t]*'.*'[ \t]*$/  )
   {
   
#  Cut out the word "coupling" from the start to make it easier to parse.

      TextLine = CutRE( COUPLING_RE, TextLine )

#  Now the definition is of the form: coupname = "stuff"

#  Copy the coupling name

      split( TextLine, TempSplit, /[ \t]*=[ \t]*/ )

      CoupName=TempSplit[1]

#  Copy the definition into coupling array

      CoupDefStart=match( TextLine, /["'].*["'][ \t]*$/ )

      Coupling[ CoupName ] = substr( TextLine, CoupDefStart )

# Reinitialize variables.

      TempSplit[1]=""
      CoupName=""
      CoupDefStart=0
      TextLine=""

   }
   else {
      FatalError( "EvalCoupDef(): Syntactic error in COUPLING statement." )
   }  # End if
   
   return

}   # End function 

# FatalError():  Print out an error message and terminate processing.
#
# Variables:
#   ErrMessage   (local parameter)

function FatalError( ErrMessage )   {

   NopgenState=NOPGEN_FATAL

   print "Fatal Error: " ErrMessage | "cat 1>&2"

   exit

}   # End function

# CutRE():  Remove the first string matching RegExp from String.
#
# Variables:
#   RegExp   (local parameter)
#   String   (local parameter)
#   pos   (local)
#   len   (local)
#   buf   (local)

function CutRE( RegExp, String,      StrLen, REpos, RElen, PartLen, buf )   {
Debug( "CutRE(" )

   if ( length( RegExp ) == 0 ) {
      FatalError( "CutRE(): Null regular expression argument.")
   }

Debug( RegExp )

   StrLen=length( String )

   REPos=match( String, RegExp )     # Get position of RE to cut.

Debug( REPos )

   if ( REPos > 0 ) {               # Continue if found.

      RELen=RLENGTH                     # Get length of matched string

Debug( RELen )

      if ( REPos > 1 ) {    # There is a first partial string.

         PartLen=REPos - 1        # Calculate first part length.
         buf=substr( String, 1, PartLen)  # Snip it from front.
      } 


      if ( (REPos + RELen) <= StrLen ) {   # There is a last part.

         PartLen=StrLen - (REPos + RELen - 1)    # Calculate position of last part.
         buf=buf substr( String, (REPos + RELen), PartLen)  # Snip it from end. Note concatenation of buf.
      } 

   }
   else {
      buf=String
   }

Debug( "String =" buf )

   return buf

}   # End function

# CopyRE():  Copy the first string matching RegExp from String.
#
# Variables:
#   RegExp   (local parameter)
#   String   (local parameter)
#   pos   (local)
#   len   (local)
#   buf   (local)

function CopyRE( RegExp, String,      pos, len, buf )   {
Debug( "CopyRE(" )

   pos=match( String, RegExp )
   len=RLENGTH
   buf=substr( String, pos, len )

   return buf

}   # End function

# ValidBlock():  Return 0 if not found in block list, 1 if found.
#
# Variables:
#   BlockName   (local parameter)
#   Result         (local)
#   Cmmd         (local)
#   ValidCount   (local)

function ValidBlock( BlockName,      Result, Cmmd, ValidCount )   {
Debug( "ValidBlock(" )

   Cmmd = "ls -l " TEMP_DIRECTORY "/" BlockName 

   while ( Cmmd | getline Result ) {
      ValidCount++
   }

   return ValidCount

}   # End function

# Debug():  Print out an error message and continue processing.
#
# Variables:
#   ErrMessage   (local parameter)

function Debug( ErrMessage )   {

   printf( "D: %s\r\n", ErrMessage ) | "cat 1>&2"

}   # End function

# GetEnvVars():  Import and assign enviromental variables to globals.
#
# Variables:
#    DEMARCSTART_RE
#    DEMARCSTART_STRING
#    DEMARCEND_RE
#    DEMARCEND_STRING
#    STARTDM_LENGTH
#    ENDDM_LENGTH
#    TEMP_DIRECTORY

function GetEnvVars(    StringPos )   {

                           # Get the starting demarcator

   DEMARCSTART_STRING=ENVIRON[ "DEMARCSTART" ]
   STARTDM_LENGTH=length( DEMARCSTART_STRING )
   if ( STARTDM_LENGTH == 0 ) {
      FatalError( "GetEnvVars(): No starting delimiter string specified." )
   }
   for ( StringPos = 1;  StringPos <= STARTDM_LENGTH; ++StringPos ) {
      DEMARCSTART_RE=DEMARCSTART_RE "[" substr(DEMARCSTART_STRING, StringPos, 1) "]"
   }

                           # Get the ending demarcator

   DEMARCEND_STRING=ENVIRON[ "DEMARCEND" ]
   ENDDM_LENGTH=length( DEMARCEND_STRING )
   if ( ENDDM_LENGTH == 0 ) {
      FatalError( "GetEnvVars(): No ending delimiter string specified." )
   }
   for ( StringPos = 1;  StringPos <= ENDDM_LENGTH; ++StringPos ) {
      DEMARCEND_RE=DEMARCEND_RE "[" substr(DEMARCEND_STRING, StringPos, 1) "]"
   }

Debug(  "." DEMARCSTART_RE "..." DEMARCEND_RE "." )

			   # Get the temporary work directory

   TEMP_DIRECTORY=ENVIRON[ "NOPGENTMP" ]

}   # End function
# leftoff
#GAWK.EXE: fatal error: Unmatched \(: / ( TableName, ColumnName, ListDelimiter )
#In fieldnames (/
#  input line number 89, file `patternfile'
#  source line number 949, file `e:/nopgen/nopgen.awk'
#
