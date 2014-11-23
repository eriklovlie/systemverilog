#!/usr/bin/env python

#
# Regenerate ANTLR parser from grammar.
# Also generates the lexical token constants (required by both ANTLR and the scala lexer).
#

import os
import subprocess

# Package and dir for generated java/scala code.
package = "com.github.misfornoyd.systemverilog.generated"
javaDir = os.path.join("src/main/java", package.replace('.', '/'))
scalaDir = os.path.join("src/main/scala", package.replace('.', '/'))

if not os.path.isdir(javaDir):
	raise Exception("Directory for generated java sources does not exist")
if not os.path.isdir(scalaDir):
	raise Exception("Directory for generated scala sources does not exist")

# NOTE: running this script will overwrite the following files:
antlrLexerTokens = os.path.join(javaDir, "SVLexer.tokens")
scalaLexerTokens = os.path.join(scalaDir, "LexerTokens.scala")

# List of lexical token types. ANTLR needs a tokens file with such
# a list (including numberical value), and this must correspond to what
# the actual lexer produces as well.

# Special-cased tokens
tokens_special = [
	# error token, produced when the lexer finds an invalid token
	("ERROR",               ""),
	("LIT_STRING",          "string-literal"),
	("LIT_NUM",             "number-literal"),
	("LIT_UNBASED_UNSIZED", "unbased-unsized-literal"),
	("LIT_TIME",            "time-literal"),
	("ID",                  "identifier"),
	("SYSTEM_ID",           "system-identifier"),
	("TIMESCALE",           "`timescale"),
	("DOLLAR_UNIT",         "$unit"),
	("DOLLAR_ROOT",         "$root"),
	("DOLLAR_FATAL",        "$fatal"),
	("DOLLAR_ERROR",        "$error"),
	("DOLLAR_WARNING",      "$warning"),
	("DOLLAR_INFO",         "$info"),
	("DOLLAR_SETUP",        "$setup"),
	("DOLLAR_HOLD",         "$hold"),
	("DOLLAR_SETUPHOLD",    "$setuphold"),
	("DOLLAR_RECOVERY",     "$recovery"),
	("DOLLAR_REMOVAL",      "$removal"),
	("DOLLAR_RECREM",       "$recrem"),
	("DOLLAR_SKEW",         "$skew"),
	("DOLLAR_TIMESKEW",     "$timeskew"),
	("DOLLAR_FULLSKEW",     "$fullskew"),
	("DOLLAR_PERIOD",       "$period"),
	("DOLLAR_WIDTH",        "$width"),
	("DOLLAR_NOCHANGE",     "$nochange"),
	("KW_1STEP",            "1step"),
]

# Operators and other similar terminals, which are lexed greedily.
# Haven't spent much energy in naming these.
tokens_operators = [
	("DOLLAR",              "$"),
	("HASH",                "#"),
	("HASH2",               "##"),
	("HASH_SUB_HASH",       "#-#"),
	("HASH_EQ_HASH",        "#=#"),
	("AT_SIGN",             "@"),
	("APOSTROPHE",          "'"),
	("DOT",                 "."),
	("COLON",               ":"),
	("COLON_EQ",            ":="),
	("COLON_DIV",           ":/"),
	("COLON2",              "::"),
	("SEMI",                ";"),
	("COMMA",               ","),
	("LPAREN",              "("),
	("RPAREN",              ")"),
	("LSQUARE",             "["),
	("RSQUARE",             "]"),
	("LCURLY",              "{"),
	("RCURLY",              "}"),
	("QUE",                 "?"),
	("NOT",                 "!"),
	("NOT_EQ",              "!="),
	("NOT_EQ2",             "!=="),
	("NOT_EQ_Q",            "!=?"),
	("MOD",                 "%"),
	("MOD_EQ",              "%="),
	("AND",                 "&"),
	("AND2",                "&&"),
	("AND3",                "&&&"),
	("AND_EQ",              "&="),
	("MUL",                 "*"),
	("MUL2",                "**"),
	("MUL_EQ",              "*="),
	("MUL_GT",              "*>"),
	("ADD",                 "+"),
	("ADD2",                "++"),
	("ADD_EQ",              "+="),
	("ADD_COLON",           "+:"),
	("SUB",                 "-"),
	("SUB2",                "--"),
	("SUB_EQ",              "-="),
	("SUB_GT",              "->"),
	("SUB_GT2",             "->>"),
	("SUB_COLON",           "-:"),
	("DIV",                 "/"),
	("DIV_EQ",              "/="),
	("LT",                  "<"),
	("LT_SUB_GT",           "<->"),
	("LT2",                 "<<"),
	("LT3",                 "<<<"),
	("LT3_EQ",              "<<<="),
	("LT2_EQ",              "<<="),
	("LT_EQ",               "<="),
	("EQ",                  "="),
	("EQ2",                 "=="),
	("EQ_GT",               "=>"),
	("EQ3",                 "==="),
	("EQ2_Q",               "==?"),
	("GT",                  ">"),
	("GT_EQ",               ">="),
	("GT2",                 ">>"),
	("GT2_EQ",              ">>="),
	("GT3",                 ">>>"),
	("GT3_EQ",              ">>>="),
	("XOR",                 "^"),
	("XOR_EQ",              "^="),
	("XOR_INV",             "^~"),
	("OR",                  "|"),
	("OR_EQ",               "|="),
	("OR2",                 "||"),
	("OR_SUB_GT",           "|->"),
	("OR_EQ_GT",            "|=>"),
	("INV",                 "~"),
	("INV_AND",             "~&"),
	("INV_XOR",             "~^"),
	("INV_OR",              "~|"),
]

def get_keyword_tokens():
	with open('sv_keywords.txt', 'r') as f:
		lines = f.readlines()
	tokens = []
	for line in lines:
		kw = line.strip()
		tokname = "KW_{}".format(kw.upper())
		tokens.append( (tokname, kw) )
	return tokens

def regen():
	print "Running ANTLR and generating parser java source..."

	tokens_keywords = get_keyword_tokens()

	tokens = tokens_special + tokens_operators + tokens_keywords

	# start from 1, since this appears to be what ANTLR generates from its own lexers.
	startIndex = 1

	# generate ANTLR tokens file
	try:
		os.makedirs(os.path.dirname(antlrLexerTokens))
	except:
		pass

	with open(antlrLexerTokens, "w") as f:
		i = startIndex
		for ttype, _ in tokens:
			f.write("{} = {}\n".format(ttype, i))
			i += 1

	with open(scalaLexerTokens, "w") as f:
		# generate scala lexer constants
		f.write("// NOTE: this file is automatically generated.\n")
		f.write("package {}\n".format(package))
		f.write("\n")
		# generate scala singleton object with mapping from token type to string
		f.write("object LexerTokens {\n")
		f.write("\n")
		i = startIndex
		for ttype, _ in tokens:
			f.write("  final val {} = {}\n".format(ttype, i))
			i += 1
		f.write("\n")
		f.write("  val tokenNames = Array(\n")
		for i in range(startIndex):
			f.write('    "",\n')
		for toktype, _ in tokens:
			f.write('    "{}",\n'.format(toktype))
		f.write('    "DUMMY")\n')
		f.write("\n")
		f.write("  val tokenConstText = Array(\n")
		for i in range(startIndex):
			f.write('    "",\n')
		for _, text in tokens:
			f.write('    "{}",\n'.format(text))
		f.write('    "DUMMY")\n')
		f.write("\n")
		f.write("  val keywords = Map(\n")
		for kw_index, (toktype, kw) in enumerate(tokens_keywords):
			f.write('    "{}" -> {}'.format(kw, toktype))
			if kw_index == len(tokens_keywords) - 1:
				f.write(')\n')
			else:
				f.write(',\n')
		f.write("\n")
		f.write("  val operators = Map(\n")
		for index, (toktype, op) in enumerate(tokens_operators):
			f.write('    "{}" -> {}'.format(op, toktype))
			if index == len(tokens_operators) - 1:
				f.write(')\n')
			else:
				f.write(',\n')
		f.write("\n")
		f.write('  val operatorPattern = """(?s)(')
		ops_by_length = sorted([op for (_, op) in tokens_operators], key=lambda x: len(x), reverse=True)
		max_length = 0
		for index, op in enumerate(ops_by_length):
			max_length = max(max_length, len(op))
			f.write('\Q{}\E'.format(op))
			if index == len(tokens_operators) - 1:
				f.write(').*""".r\n')
			else:
				f.write('|')
		f.write('  val operatorMaxLength = {}\n'.format(max_length))
		f.write("\n")
		f.write("}\n")

	# run ANTLR on the grammar
	subprocess.check_call("java -jar lib/antlr4-4.2.2-complete.jar -o {} SVParser.g4".format(javaDir), shell=True)

if __name__ == "__main__":
	regen()
