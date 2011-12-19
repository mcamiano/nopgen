# NOpGen.Awk program to generate code.
# Copyright 1992 by Mitch C. Amiano
# All Rights Reserved.
# No claim is made as to the appropriateness of this software to any task.
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
# History: 
#   March 28, 1993   	Major milestone: core-dumps were occuring from a bug in GNU-AWK
#                       which manifests itself when the 'cmd | getline var' construct is
#                       used too many times.  The solution was to use the 
#                       'getline < file > 0' construct instead.  NOpGen is now 
#                       operating with small but substantive pattern files. The
#   			performance, however, is horrible, at about .8 min per 
#                       pattern line.
#   				

# Action 1: Initialize program before input.

# Beginnings:
#  1. Import the demarcation RE's.
#  2. Calculate and store the size of the demarcation RE's.
#     This is so that they can be removed from statements and text.
#  3. Set up some generally useful regular expressions.
#  4. Initialize global arrays for name spaces, etc.

BEGIN { RS = "\n"; ORS="\n"

# Set up Environmental globals 

   GetEnvVars()
   NOPGEN_VERSION=1.0

# RegExp patterns used to successively tear apart text into Nopgen statements.

   WHITESPACE_RE="[ \t]*"
   PARSE_RE="^.*" DEMARCSTART_RE "|" DEMARCEND_RE ".*" DEMARCSTART_RE "|" DEMARCEND_RE ".*$"
   PRETEXT_RE="^.+" DEMARCSTART_RE
   NOTPRETEXT_RE="$|"DEMARCSTART_RE 
   #NOTPRETEXT_RE=DEMARCSTART_RE
   #STATEMENT_RE=PRETEXT_RE ".*" DEMARCEND_RE ".*$"
   COMMAND_RE=DEMARCSTART_RE ".*" DEMARCEND_RE

# RegExp patterns used to parse Nopgen statements themselves.

   BLOCK_RE= "^[ \t]*[Bb][Ll][Oo][Cc][Kk][ \t]+"
   ENDBLOCK_RE= "^[ \t]*[Ee][Nn][Dd][ \t]*[Bb][Ll][Oo][Cc][Kk][ \t]*" WHITESPACE_RE
   EVALUATE_RE="^[ \t]*[Ee][Vv][Aa][Ll][Uu][Aa][Tt][Ee][ \t]+" 
   EVAL_INDENT_RE="^[ \t]*[Ii][Nn][Dd][Ee][Nn][Tt]" 
   SIMPLECOUP_RE= "^[ \t]*[a-zA-Z0-9_]+[ \t]*$"  
   PASTE_RE= "^[ \t]*[Pp][Aa][Ss][Tt][Ee][ \t]+" 
   COUPLING_RE= "^[ \t]*[cC][oO][uU][pP][lL][iI][nN][gG][ \t]+" 
   COMMENT_RE="^[(].*[)]$"
   KILL_LINE_RE="^[%]$"

   BLOCKNAME_RE="[ \t]*[a-zA-Z0-9_]+" 
   COUPNAME_RE=BLOCKNAME_RE
   PARAMNAME_RE=BLOCKNAME_RE

   #PARAMLIST_RE="[ \t]*[(]([ \t]*[^)]+[ \t]*)*[)][ \t]*"
   #PARAMLIST_RE="[ \t]*[(][^)]*[)][ \t]*"
   PARAMLIST_RE="[ \t]*[(]([ \t]*[^ ()\t]+[ \t]*)*[)][ \t]*"

   PARAMS_RE="([ \t]*[a-zA-Z0-9_]+[ \t]*,?[ \t]*)+"
   PARAMS_SEPER_RE="[ \t]*,[ \t]*"
   PARAMS_DFLT_RE="[ \t]*=[ \t]*\"[^ \t]+\"[ \t]*"
   UNLESSNULL_RE="[ \t]*[Uu][Nn][Ll][Ee][Ss][Ss][ \t]*[Nn][Uu][Ll][Ll][ \t]*"

   COUPRESULTS_SEPER_RE=" "

# Nopgen program state constants.

   NOPGEN_READING=1   
   NOPGEN_WRITING=2
   NOPGEN_REREADING=3
   NOPGEN_FATAL=-1
   
# Nopgen program state variables.

   NopgenState=NOPGEN_READING
   CurrentBlock="fulltext"       # Used to process blocks of text.
   StatementsFound=0             # When 1, forces another parse of text
   OldTempFile=""             # Saves previous pass' temporary file name
   IngoreRestOfLine=0         # Tells parser to overlook rest of input line
   NewLineFound=0         # Tells recycle routine that there were no newlines
   
# Nopgen program configuration constants

   SHELLPROG="d:/bin/sh.exe"       # Used to process couplings

# Nopgen language name space arrays

     # Names and index number of defined blocks
     # Idx = [ "Blkname" ]
   Block["fulltext"]=0
   BlockCount=0

     # Count of block parameters
     # Idx = [ "Blkname" ]
   NumBlockParams["fulltext"]=0

     # Most current value of a BLOCK parameter
     # Idx = [ "Blkname" "," "ParamIdxNum" ] 
   BlockParamValue[ "fulltext" "," "" ]=""

     # Default value of a BLOCK parameter
     # Idx = [ "Blkname" "," "ParamIdxNum" ] 
   BlockParamDflt[ "fulltext" "," "" ]=""

      # BLOCK parameters' Index Numbers 
      # for use with BlockParamValue, and for validating parameter names
      # Idx = [ "Blkname" "," "BlkParamName" ]
   BlockParamNum[ "fulltext" "," ]=0

      # BLOCK parameter names
      # to loop through each parameter defined for a block
      # Idx = [ "Blkname" "," "ParamIdx" ]
   BlockParamName[ "fulltext" "," ]=""

      # BLOCK parameters name lookup table
      # for use with validating of coupling parameter names
      # Idx = [ "Blkname" "," "BlkParamName" ]
   BlockParamLookup[ "fulltext" "," ]=0

      # Names and definitions of couplings
      # Idx = [ "Coupname" ]
   Coupling[ "COPY_ONCE" ]="-c echo 1" 
   Coupling[ "INDENT" ]="" 
   Coupling[ "COPY_TWICE" ]="-c echo 1\n2;" 
   Coupling[ "NOPGEN_VERSION" ]="-c echo 'NOpGen Version "  NOPGEN_VERSION " Dated '`date`" 

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
debug_it=0

# Reevaluate the old fulltext until no more statements appear
   NopgenState=NOPGEN_REREADING

   while ( StatementsFound == 1 ) {
      ++IterationNumber

      if ( NewLineFound==0 ) {
         NewLineFound=1
         HandleText( "", "yes" )
      }
      close( TEMPFILE )     # Close latest fulltext

      OldTempFile = TEMPFILE

      StatementsFound=0     # Assume there are no more statements to be found

# Open temp file for "fulltext", for output
      OpenTempFile( TEMP_DIRECTORY, CurrentBlock IterationNumber )


      ReprocessLines( OldTempFile )
   }

   close( TEMPFILE )     # Close fulltext, the last referenced parse file

   NopgenState=NOPGEN_WRITING
   ProcessOutput()
}


# ReprocessLines():  store it or forward for more processing.
#
# Variables:

function ReprocessLines( OldTempFile,      CommandLine, NextPassText )   {

   CommandLine = sprintf( "%s", OldTempFile  )

   while ( getline NextPassText < CommandLine > 0 ) {
      ProcessLines( NextPassText )
   }
   close( CommandLine )

   return

}   # End function


# ProcessOutput():  store it or forward for more processing.
#
# Variables:

function ProcessOutput(      CommandLine, LastPassText )   {

   CommandLine = sprintf( "%s", TEMPFILE  )

   while ( getline LastPassText < CommandLine > 0 ) {
      ProcessLines( LastPassText )
   }
   close( CommandLine )

   return

}   # End function


# ProcessLines():  store it or forward for more processing.
#
# Variables:
#   Stuff   (local parameter)
#   STATEMENT_RE   (global constant)

function ProcessLines( Stuff )   {

# Check line for pattern characteristic of a nopgen statement.

   if ( match( Stuff, COMMAND_RE ) == 0 ) {   # No match
      HandleText( Stuff, "yes" ) 
      NewLineFound=1
   }
   else {                                 # It has a statement inside it
                                          # Figure out which one(s)
      StatementsFound=1
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
   CommandPos, CommandLength, Command,
   NoNewLine ) {
#NDebug( "ParseTextLine: " TextLine )

   while( length( TextLine ) > 0 )  {              # Continue until used up
#NDebug( "   while: " TextLine )

# Cut and paste any leading non-statement text.

      PretextPos=match( TextLine, NOTPRETEXT_RE )

      if ( PretextPos > 1 ) {                         # Leading text found

	 PretextLength=PretextPos-1
	 Pretext=substr( TextLine, 1, PretextLength )

	 TextLine = substr( TextLine, PretextPos )

	 HandleText( Pretext, "no" )                  # Stored w/out newline
      }   # End if

# The next part must be text within demarcation strings.
# It could also have more trailing text and statements intermixed.

# Parse and cut out the command.  Then case it.

      CommandPos=match( TextLine, DEMARCSTART_RE ) 

      if ( CommandPos >= 1 ) {    # Command found in remainder
                                  # Cut out the command, removing demarcations.

                                  # Length here includes demarcations.

         CommandLength=CommandPos + match( TextLine, DEMARCEND_RE )
            + ENDDM_LENGTH

                                  # Get the actual command text

         Command=substr( TextLine, CommandPos + STARTDM_LENGTH, 
            CommandLength - (STARTDM_LENGTH + ENDDM_LENGTH))

            # Cut the command out of line, with demarcation strings.

         TextLine = substr( TextLine, CommandLength+1 ) 

         CaseCommand( Command )      # Dispatch the proper functions.
         if ( IgnoreRestOfLine == 1 ) { 
            IgnoreRestOfLine = 0
            return
         }
         
      }   # End if

   }   # End while

      if (  NopgenState != NOPGEN_WRITING ) {
         HandleText( "", "yes" )       # Force increment of line in temp file.
         NewLineFound=1
      } else {
         HandleText( "", "no" )       # Don't force increment of line in temp file.
      }

}   # End function

# HandleText():  Store text in temp file for output later.
#
# Variables:
#   TextLine   (local parameter)
#   Increment   (local parameter)

function HandleText( TextLine, Increment, CR ) {
CR="\n"

# Throw the text into the temp file(s).
   
   if ( NopgenState != NOPGEN_WRITING ) {
      if ( Increment != "no" ) {
	 printf( "%s%s", TextLine, CR ) >> TEMPFILE
      }
      else {
	 printf( "%s", TextLine ) >> TEMPFILE
      }
   }
   else {
      TextLine=CutRE( "[]", TextLine )
      if ( Increment != "no" ) {
	 printf( "%s%s", TextLine, CR ) 
      }
      else {
	 printf( "%s", TextLine )
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
#NDebug( "CaseCommand: " stmnt )

# Action: Comments (anything within demarcations and immediate parenthesis).
# Note that a comment must not have any characters between the parens and
# the demarcation strings.

   if ( stmnt ~ COMMENT_RE  ) {             # Do action in any state.
      # Do nothing at all for comments.
      # This way, the comment is effectively 'cut' from the output.
      return
   }

# Action: Kill Rest Of Line  ( Percent Sign )
# Ignore rest of input line, including newline
#
   if ( stmnt ~ KILL_LINE_RE  ) {        # Do action in any state.
      if (  NopgenState != NOPGEN_READING && CurrentBlock == "fulltext" )  {
         # Do nothing at all for comments.
         # This way, the comment is effectively 'cut' from the output.
         IgnoreRestOfLine = 1
         return
      }
      else {   # Replace it in its pristine form.
	 HandleText( DEMARCSTART_STRING, "no" )      # Stored w/out newline
	 HandleText( stmnt, "no" )                  # Stored w/out newline
	 HandleText( DEMARCEND_STRING, "no" )      # Stored w/out newline
	 return
      }
   }

# BLOCK statements.               Apply to any state.
# Defect: End Block phrase not matched.

   if ( stmnt ~ BLOCK_RE ) {
      StartStoringBlock( stmnt )
      return
   }

# END BLOCK statements.           Apply to any state.

   if ( stmnt  ~ ENDBLOCK_RE ) {
      EndStoringBlock( stmnt )
      return
   }

# Action: EVALUATE statements.            Do only in output state.

   if ( stmnt ~  EVALUATE_RE )  {
      if (  NopgenState != NOPGEN_READING && CurrentBlock == "fulltext" )  {
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

      if (  NopgenState != NOPGEN_READING && CurrentBlock == "fulltext" )  {
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

      if (  NopgenState != NOPGEN_READING && CurrentBlock == "fulltext" )  {
   
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

      if (  NopgenState != NOPGEN_READING && CurrentBlock == "fulltext" )  {
   
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

# Increment EvalId to identify current EVALUATE statement and temp file.

   EvalId += 1

# Parse statement into command line and parameters.

# Remove the EVALUATE keyword to simplify parsing.

   stmnt=CutRE( EVALUATE_RE, stmnt )

# Copy and cut out coupling name.

   CoupStr=CopyRE( COUPNAME_RE, stmnt )
   stmnt=CutRE( COUPNAME_RE, stmnt)

# Copy and store coupling parameters in Params
   stmnt=CutRE( "^[ \t]*[(]",  stmnt )
   stmnt=CutRE( "[)][ \t]*$",  stmnt )
   TempParamNum = split( stmnt, Params, PARAMS_SEPER_RE )

# Handle any 'Builtin' evaluate couplings here, before user-defined couplings
   if ( CoupStr ~ EVAL_INDENT_RE ) {
      #if ( ! (CoupStr in Coupling) ) {
         #Coupling[ CoupStr ] = Coupling[ "INDENT" ]
      #}
#leftoff
         ParamLine=Coupling[ CoupStr ]
         for ( TempBufIdx=1; TempBufIdx <= TempParamNum;  ++TempBufIdx ) {
             ParamLine = ParamLine Params[ TempBufIdx ]
         }   # End for
         HandleText( ParamLine, "no" )
      return
   }

# Loop through each coupling parameter and create line of parameters' values
   ParamLine=""
   for ( TempBufIdx=1; TempBufIdx <= TempParamNum;  ++TempBufIdx ) {
       ParamLine = ParamLine " " Params[ TempBufIdx ]
#      TempName = CurrentBlock "," Param[ TempParamBuf[ TempBufIdx ] ]
#      if ( TempName in BlockParamLookup ) {
#         ParamLine = ParamLine " " BlockParamValue[ CurrentBlock "," BlockParamNum[ TempName ] ]
#      }
#      else {
#         ParamLine = "Evaluating couple parameters: " ParamLine 
#         FatalError( ParamLine )
#      }   # End if
   }   # End for

# Create temporary file for evaluation text storage.
# Better to keep it in temp file because EVALUATE recursion could 
# overflow the program's limits.
   TextFile = sprintf( "%s/evaluate.%d", TEMP_DIRECTORY,  EvalId )

# Create a command line to execute the coupling.
   CommandLine=SHELLPROG " " Coupling[ CoupStr ] " " ParamLine

# Execute the command line. It is a fatal error if it fails.
   if ( system( CommandLine "> " TextFile ) == -1 ) {       # Unexpected error
      CommandLine=" Evaluating couple: " CommandLine
      FatalError( CommandLine )
   }

# Then recycle the lines obtained through nopgen.
   while ( getline TextLine < TextFile > 0 ) {
      HandleText( TextLine, "yes" )
   }
   close( CommandLine )

   return

}   # End function

# StartStoringBlock():  Initialize block recording and state.
#
# Variables:
#   BlockCmd    (local parameter)
#   CurrentBlock   (global variable)
#   Blkname   (local)
#   TEMP_DIRECTORY   (global constant)
#   BlockParamValue[]   (global buffer)
#   BlockParamNum[]   (global buffer)
#   TempParamBuf[]   (local buffer)
#   TempParamNum     (local)
#   TempDfltVal      (local)
#   TempBufIdx       (local)

function StartStoringBlock( BlockCmd,       Blkname, TempParamName, TempParamBuf, TempParamNum, TempDfltVal, TempBufIdx ) {

# Validate the program state.

   if ( CurrentBlock != "fulltext" ) {          # Illegal Nesting Error

      FatalError( " generating text.  Illegal nesting of BLOCKs." )

   }
   else {                        # Start recording the current block.

# Cut out the BLOCK keyword.

      BlockCmd = CutRE( BLOCK_RE, BlockCmd )

# Parse out the block name into Blkname. The validate it.
#   Block names may be reused, so no duplicate check is performed 
      Blkname =""
      Blkname = CopyRE( BLOCKNAME_RE, BlockCmd )

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

# Save the block name in the block name list, and assign a number to it

      Block[ CurrentBlock ]= ++BlockCount

# Parse out the optional block parameters into BlockParamValue[]
# The index for BlockParameter is mangled from Blkname+"parametername"
# 3/19/93 changed mangling to use Blkname+param_idxnum
# The values for the parameters are the actual values of the array.

      BlockCmd = CopyRE( PARAMLIST_RE, BlockCmd )

      BlockCmd=CopyRE( PARAMS_RE,  BlockCmd )

      TempParamNum = split( BlockCmd, TempParamBuf, PARAMS_SEPER_RE )

      NumBlockParams[ CurrentBlock ] = TempParamNum

# At this point, TempParamBuf may contain nothing, or parameters
# with default assignments.  Any default assignments have to be sorted out.

      for ( TempBufIdx=1; TempBufIdx <= TempParamNum; ++TempBufIdx ) {

# Obtain the parameter name, assign it to the parameter name space array
         BlockParamName[ CurrentBlock "," TempBufIdx ] = CopyRE( PARAMNAME_RE, TempParamBuf[ TempBufIdx ] )
         BlockParamName[ CurrentBlock "," TempBufIdx ] = CutRE( "[ \t]*", BlockParamName[ CurrentBlock "," TempBufIdx ] )
         BlockParamName[ CurrentBlock "," TempBufIdx ] = CutRE( " ", BlockParamName[ CurrentBlock "," TempBufIdx ] )
         BlockParamName[ CurrentBlock "," TempBufIdx ] = CutRE( "", BlockParamName[ CurrentBlock "," TempBufIdx ] )
         BlockParamNum[ CurrentBlock "," BlockParamName[ CurrentBlock "," TempBufIdx ] ] = TempBufIdx  
         BlockParamLookup[ CurrentBlock "," BlockParamName[ CurrentBlock "," TempBufIdx ] ] = TempBufIdx  

	 if ( TempParamBuf[ TempBufIdx ]  ~ PARAMS_DFLT_RE ) {

# Defaults exist.
# Copy default value out, and snip off any leading/trailing junk.

	    TempDfltVal = CopyRE( PARAMS_DFLT_RE, TempParamBuf[ TempBufIdx ] )
	    TempDfltVal = CutRE( "^[ \t]*=[ \t]*\"", TempDfltVal )
	    TempDfltVal = CutRE( "\"[ \t]*$", TempDfltVal )

# Assign default value to array for later use

	    BlockParamDflt[ CurrentBlock "," TempBufIdx ] = TempDfltVal

# Initialize the parameter value to the default (so EVAL's can have it)
	     BlockParamValue[ CurrentBlock "," TembBufIdx ] =  TempDfltVal
	 }
	 else {       # Default does not exist. Initialize default to null.

	    BlockParamDflt[ CurrentBlock "," TempBufIdx ] = ""

# Initialize the parameter value to null (as a safeguard)
	     BlockParamValue[ CurrentBlock "," TembBufIdx ] = ""

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
#   BlockParamValue[]   (global buffer)
#   BlockParamNum[]   (global buffer)

function PasteBlock( PasteCmd, Blkname, BlockParamIdx, Coup, CoupParams, CoupParamsIdx, CoupParamLine, NumCoupParams, CoupParamsIdx, FieldSpecLine, FieldSpecs, NumFieldSpecs, FieldSpecsIdx, CommandLine, CommandLine2, BlockText, UnlessNull, ResultFields, NumResultFields, ResultIdx  ) {

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
	    FatalError( "PasteBlock(): block name given (" Blkname ") is not defined." )
         }
         else {
            if ( Blkname == CurrentBlock ) { 
               FatalError( "PasteBlock(): cannot PASTE current block." )
            }
         }
      }

# Cut out the block name

   PasteCmd = CutRE( BLOCKNAME_RE, PasteCmd )

# Parse out the coupling field specifiers.
# No validation is needed for field specifiers.
# ? leftoff ?  Shouldn't they correspond to parameters along the heirarchy ?
# The fields are used to read values from the coupling stream positionally.
# They should correspond to block parameters somewhere along the PASTE
# heirarchy.  After this PASTE is done, they are tossed into the bit bucket.
# The index for BlockParamValue is mangled from Blkname+"index num"

   FieldSpecLine = CopyRE( PARAMS_RE, PasteCmd )

# If the number of fields is zero, the paste is done without any reference
#    to the actual values returned by the coupling.  This allows a straight
#    copy operation;  the number of copies done corresponds to the number
#    of rows returned by the coupling.

   NumFieldSpecs = split( FieldSpecLine, FieldSpecs, PARAMS_SEPER_RE )
   for ( FieldSpecsIdx = 1; FieldSpecsIdx <= NumFieldSpecs; ++FieldSpecsIdx ) {
      FieldSpecs[ FieldSpecsIdx ] = CutRE( "[ \t]*", FieldSpecs[ FieldSpecsIdx ] )
      FieldSpecs[ FieldSpecsIdx ] = CutRE( " ", FieldSpecs[ FieldSpecsIdx ] )
      FieldSpecs[ FieldSpecsIdx ] = CutRE( "", FieldSpecs[ FieldSpecsIdx ] )
   }

# If there are more field specifiers than Block parameters,
#    it is not so-good, but not a fatal error either. The extra parameter
#    specifiers in the command line will be ignored.

# Cut out the field specifiers from the paste command line.

   PasteCmd = CutRE( "^[ \t]*[(]",  PasteCmd )
   PasteCmd = CutRE( PARAMS_RE, PasteCmd )
   PasteCmd = CutRE( "[)][ \t]*[Ii][Nn][ \t]*",  PasteCmd )

# The field specifiers are now prepared and contained in FieldSpecs[],
#    which is indexed by its ordinal number.

# Parse out the coupling name into coup.

   Coup = CopyRE( COUPNAME_RE, PasteCmd )

   PasteCmd = CutRE( COUPNAME_RE, PasteCmd )

# Validate the coupling. If it doesn't exist, the heck with it. It's a comment.

   if ( Coup in Coupling ) {

# Parse out the coupling parameters into CoupParams[], indexed by param name.
# The coupling parameters are considered to be variables defined in a 
# previous PASTE operation, as part of a coupling-field-specifier-list,
# or from default BLOCK parameters.

      CoupParamsLine = CopyRE( PARAMS_RE, PasteCmd )
      PasteCmd = CutRE( "[ \t]*[(]", PasteCmd )
      PasteCmd = CutRE( PARAMS_RE, PasteCmd )
      PasteCmd = CutRE( "[)][ \t]*$", PasteCmd )

      NumCoupParams = split( CoupParamsLine, CoupParams, PARAMS_SEPER_RE )

# Coupling parameter validation is disabled. The removal of recursive 
# ProcessLines() calls means that block parameters are no longer defined
# within the enclosing BLOCK scope. Params must be referenced using $-param-$
# instead, as in "in couplname ( $-param-$ )".
# Validate the coupling parameters.  If they are not assigned in a 
#   previous or current block, then it is a fatal error.
      CommandLine = SHELLPROG " " Coupling[ Coup ]
      for ( CoupParamsIdx = 1; CoupParamsIdx <= NumCoupParams; ++CoupParamsIdx ) {
	 CommandLine = CommandLine " " CoupParams[ CoupParamsIdx ]
#	 BlockParamIdx = Blkname "," CoupParams[ CoupParamsIdx ]
#	 if ( BlockParamIdx in BlockParamLookup ) {
#	     CommandLine = CommandLine " " BlockParamValue[ BlockParamIdx ]
#	 }
#	 else {
#	    FatalError( "Undefined coupling parameter: " BlockParamIdx )
#	 }   # End if
      }   # End for

# Check for the UNLESS NULL clause, which specifies that the paste operation
#   will evaluate to nothing if no coupling fields are returned.

      UnlessNull = match ( PasteCmd, UNLESSNULL_RE ) 

# Now, process the coupling and copy the block for each 
# space-delineated field in the coupling output stream

      while ( CommandLine | getline Results  ) {

# chop the coupling output results apart into component fields

	 NumResultFields = split( Results, ResultFields, COUPRESULTS_SEPER_RE )

# Check to see if the line is null or only a remainder with only a few fields 

	 if (( (NumResultFields < NumFieldSpecs) && (UnlessNull > 0) ) || (NumResultFields >= NumFieldSpecs) ) {

# Default values had been assigned to block parameters previously,
#  but they may have been overwritten by previous PASTE statements;
#  They should be reset to the defaults here to prevent unintended replacements
	    for ( BlockParamIdx = 1; BlockParamIdx <= NumBlockParams[ Blkname ]; ++BlockParamIdx ) {
               BlockParamValue[ Blkname "," BlockParamIdx ] = BlockParamDflt[ Blkname "," BlockParamIdx ]
            }

# Assign field values to BlockParamValues to be used when substituting.
# Initialize unassigned BlockParamValue[] values from BlockParamDflt
# Use the PASTE field specifiers to remap to input stream to the correct parameters.

	    for ( ResultIdx = 1; ResultIdx <= NumResultFields; ++ResultIdx ) {

		  BlockParamIdx = Blkname "," BlockParamNum[ Blkname "," FieldSpecs[ ResultIdx ] ]

		  BlockParamValue[ BlockParamIdx ] = ResultFields[ ResultIdx ]

	    }   # End for

# We have:   
#         TEMP_DIRECTORY/Blkname
#         BlockParamValue[ Blkname "," BlockParamNum[ Blkname "," Parmname ] ]

# Loop through text line which was stored previously for this block

	    CommandLine2 = sprintf( "%s/%s", TEMP_DIRECTORY, Blkname )

	    while ( getline BlockText < CommandLine2 > 0 ) {

# Loop through each block parameter
# globally substitute each parameter name with its value
# for this we need an unadulterated (unmunged) block parameter name

	       for ( BlockParamIdx = 1;  BlockParamIdx <= NumBlockParams[ Blkname ]; ++BlockParamIdx ) {
		  gsub( DEMARCSTART_RE BlockParamName[ Blkname "," BlockParamIdx ] DEMARCEND_RE, BlockParamValue[ Blkname "," BlockParamIdx ], BlockText )
	       }

# Last leg: send the line out.

	       HandleText( BlockText, "yes" )

	    }   # End while block text
            close( CommandLine2 )

	 }   # End if UNLESS NULL or full command line

      }   # End while coupling results
      close( CommandLine )

   }   # End if

   return

}   # End function

# EvalSimpleCoup():  evaluate a simple coupling and include its text
#
# Variables:
#   coup   (local parameter)
#   InputText   (local)

function EvalSimpleCoup( coup,      InputText ) {

   while ( Coupling[ coup ] | getline InputText ) {
      HandleText( InputText, "yes" )
   }
   close( Coupling[ coup ] )

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

      CoupDefStart=match( TextLine, /["'].*["']/ )

      Coupling[ CoupName ] = substr( TextLine, CoupDefStart+1, RLENGTH-2 )

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

   print "Fatal Error: " ErrMessage | ENVIRON[ "CATPROG" ] " 1>&2"
   close( ENVIRON[ "CATPROG" ] " 1>&2" )

   exit

}   # End function

# CutString():  Remove the first string matching fixed RegExp from String.
#
# Variables:
#   RegExp   (local parameter)
#   String   (local parameter)
#   pos   (local)
#   len   (local)
#   buf   (local)

function CutString( RegExp, String,      StrLen, REpos, RElen, PartLen, buf )   {

   if ( length( RegExp ) == 0 ) {
      FatalError( "CutString(): Null search string argument.")
   }

   StrLen=length( String )

   REPos=index( String, RegExp )     # Get position of RE to cut.

   if ( REPos > 0 ) {               # Continue if found.

      RELen = length( RegExp )

      if ( REPos > 1 ) {    # There is a first partial string.

         PartLen=REPos - 1        # Calculate first part length.
         buf=substr( String, 1, PartLen)  # Snip it from front.
      } 

      if ( (REPos + StrLen) <= StrLen ) {   # There is a last part.

         PartLen=StrLen - (REPos + RELen - 1)    # Calculate position of last part.
         buf=buf substr( String, (REPos + RELen), PartLen)  # Snip it from end. Note concatenation of buf.
      } 
   }
   else {
      buf=String
   }

   return buf

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

   if ( length( RegExp ) == 0 ) {
      FatalError( "CutRE(): Null regular expression argument.")
   }

   StrLen=length( String )

   REPos=match( String, RegExp )     # Get position of RE to cut.

   if ( REPos > 0 ) {               # Continue if found.

      RELen=RLENGTH                     # Get length of matched string

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
   pos=match( String, RegExp )
   len=RLENGTH
   if ( len < 1 ) {    # There is no match
      buf=""
   }
   else {
      buf=substr( String, pos, len )
   }
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

   if ( BlockName in Block )  {
      ValidCount=1
   }
   else {
      ValidCount=0
   }

   return ValidCount

}   # End function

# NDebug():  Print out an error message and continue processing.
#
# Variables:
#   ErrMessage   (local parameter)
function NDebug( ErrMessage )   {
print( "Debug: " ErrMessage ) 
return
}

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
			   # Get the temporary work directory
   TEMP_DIRECTORY=ENVIRON[ "NOPGENTMP" ]

}   # End function
