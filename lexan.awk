# lexan.Awk program to lexically analyze code
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
# Output interface: stdout
#
# History: 

# Action 1: Initialize program before input.

BEGIN { RS = "\$| +|\n+|\t+"; ORS="\n"

   LEX_READING=0
   LEX_WRITING=1
   LEX_ERROR=-1

   lexstate=LEX_READING
}

# Action 2: Read text from the pattern files.

lexstate == LEX_READING {

   printf( "Token=%s\n",  $0 )

}   # End action


# Action 3: Process for output

END {
   print "Done Lexing"
}
